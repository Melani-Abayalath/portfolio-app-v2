import ballerina/sql;

public type PortfolioAllocationRow record {
    @sql:Column {name: "portfolio_id"}
    string portfolioId;

    @sql:Column {name: "category_code"}
    string categoryCode;

    @sql:Column {name: "category"}
    string category;

    @sql:Column {name: "category_mv"}
    decimal categoryValue;
};

public type RedshiftConfig record {|
    string jdbcUrl;
    string user;
    string password;
    int maxOpenConnections = 5;
    int minIdleConnections = 1;
|};
