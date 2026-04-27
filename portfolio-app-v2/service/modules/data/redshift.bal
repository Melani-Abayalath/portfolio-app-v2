import ballerina/log;
import ballerina/sql;
import ballerina/time;
import ballerinax/aws.redshift;
import ballerinax/aws.redshift.driver as _;

public configurable RedshiftConfig redshiftConfig = ?;

public final redshift:Client redshiftClient = check initializeRedshiftClient();

isolated function initializeRedshiftClient() returns redshift:Client|error {
    int startTime = time:utcNow()[0];
    log:printDebug("[DEBUG] Starting Redshift client initialization");

    sql:ConnectionPool connectionPool = {
        maxOpenConnections: redshiftConfig.maxOpenConnections,
        minIdleConnections: redshiftConfig.minIdleConnections
    };

    redshift:Client|error dbClient = new (
        url      = redshiftConfig.jdbcUrl,
        user     = redshiftConfig.user,
        password = redshiftConfig.password,
        connectionPool = connectionPool
    );

    if dbClient is redshift:Client {
        log:printInfo("[INFO] Successfully connected to Redshift");
    } else {
        log:printError("[ERROR] Failed to connect to Redshift", dbClient);
    }

    decimal elapsed = <decimal>(time:utcNow()[0] - startTime);
    log:printDebug("[DEBUG] Redshift client init completed", elapsedSeconds = elapsed);
    return dbClient;
}

public isolated function fetchPortfolioAllocation(
        string correlationId, string portfolioId, boolean includeNegativeValues)
        returns PortfolioAllocationRow[]|error {

    sql:ParameterizedQuery q = buildPortfolioAllocationQuery(portfolioId, includeNegativeValues);

    int startTime = time:utcNow()[0];
    log:printDebug("[DEBUG] Executing fetchPortfolioAllocation query",
        correlationId = correlationId,
        portfolioId = portfolioId);

    stream<PortfolioAllocationRow, sql:Error?> resultSet = redshiftClient->query(q);

    decimal elapsed = <decimal>(time:utcNow()[0] - startTime);
    log:printDebug("[DEBUG] Query executed",
        correlationId = correlationId,
        elapsedSeconds = elapsed);

    startTime = time:utcNow()[0];
    PortfolioAllocationRow[] rows = check from PortfolioAllocationRow row in resultSet
        select row;

    elapsed = <decimal>(time:utcNow()[0] - startTime);
    log:printDebug("[DEBUG] Rows fetched from stream",
        correlationId = correlationId,
        rowCount = rows.length(),
        elapsedSeconds = elapsed);

    if rows.length() == 0 {
        log:printDebug("[DEBUG] No rows returned for portfolioId",
            portfolioId = portfolioId,
            correlationId = correlationId);
        return [];
    }
    return rows;
}
