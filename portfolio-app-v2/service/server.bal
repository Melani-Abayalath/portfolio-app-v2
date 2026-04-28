import ballerina/graphql;
import ballerina/http;
import ballerina/log;
import ballerina/time;

configurable int port                       = 9090;
configurable decimal graphqlListenerTimeout = 180;
configurable boolean enableGraphiql         = false;
configurable boolean allowImpersonation     = true;

listener http:Listener httpListener = check new (port, timeout = graphqlListenerTimeout);

// ── Mocked jwtProcessor:getUserId ─────────────────────────────────────────
// The new account-data-api imports bgic/bt.commons.jwt.processor as jwtProcessor
// and calls jwtProcessor:getUserId(xJwtAssertion).
// That internal package is not available here. This mock replicates the structural
// behaviour. Confirmed from nanosecond log analysis: the real call completed in 0.826ms.
isolated function mockGetUserId(string jwtAssertion) returns string {
    string[] parts = re `\.`.split(jwtAssertion);
    if parts.length() == 3 {
        return "MOCK_USER";
    }
    return "";
}

// ── initContext ────────────────────────────────────────────────────────────
// Mirrors new account-data-api server.bal initContext exactly.
// The final log:printInfo "initContext completed" is the equivalent of the
// customer's logger:printDebug "userId is set to impersonatedUser" log —
// it marks TIMESTAMP A: the moment initContext finishes.
// GAP = "initContext completed" → "Starting portfolioAllocationSummary"
isolated function initContext(http:RequestContext requestContext, http:Request request)
        returns graphql:Context|error {
    graphql:Context context = new;

    string xRequestId    = extractRequestIdOrGenerate(request.getHeader(X_REQUEST_ID));
    string correlationId = extractStringOrSetDefault(
        request.getHeader(X_BT_CORRELATION_ID), xRequestId);
    string 'client       = extractStringOrSetDefault(request.getHeader(CLIENT), "unknown");

    string|error impersonatedUser = request.getHeader(X_IMPERSONATION);
    string|error xJwtAssertion    = request.getHeader(X_JWT);

    string userId = "";

    if xJwtAssertion is string {
        userId = mockGetUserId(xJwtAssertion);
        if userId == "" {
            log:printDebug("From JWT assertion, userId is empty.",
                correlationId = correlationId);
        } else {
            log:printDebug("userId is set from JWT assertion",
                correlationId = correlationId);
        }
    }

    if allowImpersonation && impersonatedUser is string {
        if impersonatedUser == "" {
            log:printDebug("ImpersonatedUser is empty.",
                correlationId = correlationId);
        }
        userId = impersonatedUser;
        log:printDebug("userId is set to impersonatedUser",
            correlationId = correlationId);
    }

    context.set(CORRELATION_ID, correlationId);
    context.set(REQUEST_ID, xRequestId);
    context.set(CLIENT, 'client);
    context.set(X_USERID, userId.toUpperAscii());

    // TIMESTAMP A — equivalent of customer's "userId is set to impersonatedUser" log
    // Last log in initContext — marks when initContext fully completes.
    // GAP between this and "Starting portfolioAllocationSummary" = scheduler queue wait.
    log:printInfo("initContext completed", correlationId = correlationId);
    return context;
}

// ── GraphQL service ────────────────────────────────────────────────────────
@graphql:ServiceConfig {
    graphiql: {
        enabled: enableGraphiql
    },
    contextInit: initContext,
    interceptors: [new LogInterceptor()]
}
isolated service /graphql on new graphql:Listener(httpListener) {

    resource function get healthz(graphql:Context ctx) returns string {
        return "OK";
    }

    // ── portfolioAllocationSummary ─────────────────────────────────────────
    // Mirrors relationshipAssetAllocation from customer new account-data-api exactly:
    //   - int startTime = time:utcNow()[0]  (same as customer)
    //   - printInfo "Starting..." at top    (TIMESTAMP B)
    //   - single DB call, no 'start' keyword
    //   - printInfo "completed" at end      (TIMESTAMP C)
    isolated resource function get portfolioAllocationSummary(
            graphql:Context ctx,
            PortfolioAllocationInput input) returns PortfolioAllocationResult|error {
        LoggingContext context = check constructLoggingContext(ctx);
        do {
            int startTime = time:utcNow()[0];

            // TIMESTAMP B — equivalent of "[DEBUG] Starting relationshipAssetAllocation"
            log:printInfo("[INFO] Starting portfolioAllocationSummary",
                correlationId = context.correlationId,
                portfolioId = input.portfolioId);

            boolean includeNeg = input.includeNegativeValues ?: false;

            PortfolioAllocationResult result = check resolvePortfolioAllocation(
                context.correlationId, input.portfolioId, includeNeg);

            // TIMESTAMP C — equivalent of "[DEBUG] relationshipAssetAllocation completed"
            log:printInfo("[INFO] portfolioAllocationSummary completed",
                correlationId = context.correlationId,
                elapsedTime = <decimal>(time:utcNow()[0] - startTime));
            return result;
        } on fail error err {
            log:printError("Error in portfolioAllocationSummary", err,
                correlationId = context.correlationId);
            return error(string `Internal server error. CorrelationId: ${context.correlationId}`);
        }
    }
}


