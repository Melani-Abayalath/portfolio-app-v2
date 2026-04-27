import ballerina/graphql;
import ballerina/http;
import ballerina/log;
import ballerina/time;

configurable int port                    = 9090;
configurable decimal graphqlListenerTimeout = 180;
configurable boolean enableGraphiql      = false;

// Matches configurable boolean allowImpersonation = true in new account-data-api server.bal
configurable boolean allowImpersonation = true;

listener http:Listener httpListener = check new (port, timeout = graphqlListenerTimeout);

// ── Mocked jwtProcessor:getUserId ──────────────────────────────────────────
// The new account-data-api imports bgic/bt.commons.jwt.processor as jwtProcessor
// and calls jwtProcessor:getUserId(xJwtAssertion).
// That internal package is not available here.
// This mock replicates the structural behaviour:
//   - receives the JWT header string
//   - attempts to extract a user identifier
//   - returns empty string if the header is not a valid JWT or user is not found
// Based on confirmed evidence: this call completed in 0.826ms during the load test.
// It is mocked here to preserve the structural flow without the internal dependency.
isolated function mockGetUserId(string jwtAssertion) returns string {
    // A standard JWT has three dot-separated base64url segments: header.payload.signature
    // We attempt to find the payload and return a dummy userId to mimic the call pattern.
    // In the real implementation getUserId would decode the JWT and extract a claim.
    string[] parts = re `\.`.split(jwtAssertion);
    if parts.length() == 3 {
        // Valid JWT structure detected — return a placeholder userId
        // In production this would be the decoded claim value
        return "MOCK_USER";
    }
    // Not a valid JWT — return empty string (same behaviour as real implementation
    // when userId is not found, which triggers the "userId is empty" log)
    return "";
}

// ── initContext ────────────────────────────────────────────────────────────
// Mirrors new account-data-api server.bal initContext exactly:
//   1. Extract correlation ID and request ID from headers
//   2. Process JWT assertion header → extract userId (mocked)
//   3. Apply impersonation header if allowImpersonation is true
//   4. Set all values into graphql:Context
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

    // ── JWT processing (mocked jwtProcessor:getUserId) ─────────────────────
    // In new account-data-api: userId = jwtProcessor:getUserId(xJwtAssertion)
    // Confirmed from nanosecond log analysis: this block completes in 0.826ms
    if xJwtAssertion is string {
        userId = mockGetUserId(xJwtAssertion);

        if userId == "" {
            log:printDebug("From JWT assertion, userId is empty.",
                correlationId = correlationId,
                metadata = {"userId": userId});
        } else {
            log:printDebug("userId is set from JWT assertion",
                correlationId = correlationId,
                metadata = {"userId": userId});
        }
    }

    // ── Impersonation (mirrors new account-data-api server.bal lines 40-46) ─
    if allowImpersonation && impersonatedUser is string {
        if impersonatedUser == "" {
            log:printDebug("ImpersonatedUser is empty.",
                correlationId = correlationId,
                metadata = {"userId": userId});
        }
        userId = impersonatedUser;
        log:printDebug("userId is set to impersonatedUser",
            correlationId = correlationId,
            metadata = {"userId": userId});
    }

    context.set(CORRELATION_ID, correlationId);
    context.set(REQUEST_ID, xRequestId);
    context.set(CLIENT, 'client);
    context.set(X_USERID, userId.toUpperAscii());
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

    // ── Health check ───────────────────────────────────────────────────────
    resource function get healthz(graphql:Context ctx) returns string {
        return "OK";
    }

    // ── portfolioAllocationSummary ─────────────────────────────────────────
    // Mirrors the structure of relationshipAssetAllocation from new account-data-api:
    //   - Single sequential DB call (no 'start' keyword)
    //   - constructLoggingContext at the top
    //   - Debug log at start and end with elapsed time
    //   - Error handling pattern identical to new code
    isolated resource function get portfolioAllocationSummary(
            graphql:Context ctx,
            PortfolioAllocationInput input) returns PortfolioAllocationResult|error {
        LoggingContext context = check constructLoggingContext(ctx);
        do {
            int startTime = time:utcNow()[0];
            log:printDebug("[DEBUG] Starting portfolioAllocationSummary",
                correlationId = context.correlationId,
                portfolioId = input.portfolioId,
                includeNegativeValues = input.includeNegativeValues);

            boolean includeNeg = input.includeNegativeValues ?: false;

            PortfolioAllocationResult result = check resolvePortfolioAllocation(
                context.correlationId, input.portfolioId, includeNeg);

            log:printDebug("[DEBUG] portfolioAllocationSummary completed",
                correlationId = context.correlationId,
                elapsedSeconds = elapsedSeconds(startTime));
            return result;
        } on fail error err {
            log:printError("Error in portfolioAllocationSummary", err,
                correlationId = context.correlationId);
            return error(string `Internal server error. CorrelationId: ${context.correlationId}`);
        }
    }
}
