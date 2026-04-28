import ballerina/graphql;
import ballerina/log;
import ballerina/time;

// Identical to interceptor.bal in both old and new account-data-api.
// Logs elapsed time per resolver field — does not affect execution path.
@graphql:InterceptorConfig {
    global: false
}
public readonly isolated service class LogInterceptor {
    *graphql:Interceptor;

    isolated remote function execute(graphql:Context context, graphql:Field 'field)
            returns anydata|error {
        LoggingContext ctx = check constructLoggingContext(context);

        string fieldName = 'field.getName();

        // Log when interceptor hands off to resolver — nanosecond precision
        // This is the equivalent of the customer's "userId is set to impersonatedUser"
        // timestamp — marks when initContext is complete and execution is about to begin
        time:Utc interceptorStart = time:utcNow();
        log:printInfo(string `Interceptor handoff: ${fieldName}`,
            correlationId = ctx.correlationId,
            timestampNs = interceptorStart[1]);

        var data = context.resolve('field);

        time:Utc interceptorEnd = time:utcNow();
        time:Seconds diff = time:utcDiffSeconds(interceptorEnd, interceptorStart);
        decimal elapsedMs = diff * 1000d;
        log:printInfo(string `Executed ${fieldName}`,
            elapsedTime = diff,
            elapsedMs = elapsedMs,
            correlationId = ctx.correlationId);
        return data;
    }
}
