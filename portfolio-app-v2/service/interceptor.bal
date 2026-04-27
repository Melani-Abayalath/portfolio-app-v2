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
        time:Utc startTime = time:utcNow();

        var data = context.resolve('field);

        time:Utc endTime = time:utcNow();
        time:Seconds diff = time:utcDiffSeconds(endTime, startTime);
        log:printInfo(string `Executed ${fieldName}`,
            elapsedTime = diff,
            correlationId = ctx.correlationId);
        return data;
    }
}
