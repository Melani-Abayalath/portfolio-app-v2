import portfolio_allocation_api_v2.data;

import ballerina/graphql;
import ballerina/http;
import ballerina/log;
import ballerina/time;
import ballerina/uuid;

// ── Header extraction helpers ─────────────────────────────────────────────
// Identical to portfolio-app utils.bal
isolated function extractRequestIdOrGenerate(string|http:HeaderNotFoundError header) returns string =>
    header is string && header != "" ? header : uuid:createType4AsString();

isolated function extractStringOrSetDefault(string|http:HeaderNotFoundError header, string defaultVal) returns string =>
    header is string && header != "" ? header : defaultVal;

// ── Context value helper ──────────────────────────────────────────────────
isolated function getStringContextValue(graphql:Context ctx, string key) returns string|error {
    var val = ctx.get(key);
    if val is string {
        return val;
    }
    return error(string `Context key '${key}' not found or not a string`);
}

// ── constructLoggingContext ───────────────────────────────────────────────
// Identical to both old and new account-data-api utils.bal line 550
isolated function constructLoggingContext(graphql:Context ctx) returns LoggingContext|error => {
    correlationId: check getStringContextValue(ctx, CORRELATION_ID),
    requestId:     check getStringContextValue(ctx, REQUEST_ID),
    'client:       check getStringContextValue(ctx, CLIENT)
};

// ── Elapsed time helper ───────────────────────────────────────────────────
isolated function elapsedSeconds(int startTime) returns decimal =>
    <decimal>(time:utcNow()[0] - startTime);

// ── Core orchestration ────────────────────────────────────────────────────
// Mirrors getRelationshipAssetAllocationResponse from account-data-api utils.bal:
//   - Single DB call
//   - Light in-memory aggregation
//   - Debug logging at each step
isolated function resolvePortfolioAllocation(
        string correlationId, string portfolioId, boolean includeNegativeValues)
        returns PortfolioAllocationResult|error {
    do {
        // DB query start — nanosecond precision
        time:Utc dbStart = time:utcNow();
        log:printInfo("DB query starting",
            correlationId = correlationId,
            portfolioId = portfolioId,
            timestampNs = dbStart[1]);

        data:PortfolioAllocationRow[] rows = check data:fetchPortfolioAllocation(
            correlationId, portfolioId, includeNegativeValues);

        // DB query end — nanosecond precision
        time:Utc dbEnd = time:utcNow();
        decimal dbElapsedMs = time:utcDiffSeconds(dbEnd, dbStart) * 1000d;
        log:printInfo("DB query completed",
            correlationId = correlationId,
            rowCount = rows.length(),
            dbElapsedMs = dbElapsedMs);

        // Aggregation start
        time:Utc aggStart = time:utcNow();
        AllocationSegment[] segments = [];
        decimal totalValue   = 0d;
        decimal negativeValue = 0d;

        foreach data:PortfolioAllocationRow row in rows {
            if row.categoryValue > 0d {
                totalValue += row.categoryValue;
            } else {
                negativeValue += row.categoryValue;
            }
        }

        foreach data:PortfolioAllocationRow row in rows.filter(r => r.categoryValue != 0d) {
            AllocationSegment segment = {
                name:        row.category,
                code:        row.categoryCode,
                marketValue: row.categoryValue,
                percentage:  totalValue > 0d && row.categoryValue > 0d
                    ? (row.categoryValue / totalValue) * 100d
                    : 0d
            };
            segments.push(segment);
        }

        PortfolioAllocationResult result = {
            portfolioId:  portfolioId,
            totalValue:   totalValue + negativeValue,
            segments:     segments
        };

        // Aggregation end
        time:Utc aggEnd = time:utcNow();
        decimal aggElapsedMs = time:utcDiffSeconds(aggEnd, aggStart) * 1000d;
        log:printInfo("Response constructed",
            correlationId = correlationId,
            aggElapsedMs = aggElapsedMs);

        return result;

    } on fail error err {
        return error(string `Internal error. CorrelationId: ${correlationId}, ` +
            string `Method: resolvePortfolioAllocation, Error: ${err.message()}`);
    }
}
