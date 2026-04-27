import ballerina/sql;

isolated function buildPortfolioAllocationQuery(
        string portfolioId, boolean includeNegativeValues)
        returns sql:ParameterizedQuery {

    sql:ParameterizedQuery queryPart1 =
    `SELECT pa.portfolio_id,
            pa.category,
            pa.category_code,
            SUM(pa.detail_mv) AS category_mv
     FROM perf_test.portfolio_allocation pa
     INNER JOIN perf_test.portfolio_hierarchy ph
         ON pa.entity_no = ph.subaccount_no
     WHERE pa.as_of_date IS NULL
       AND pa.portfolio_id = ${portfolioId}
       AND ph.subaccount_active = 'Y'`;

    sql:ParameterizedQuery queryPart2 =
        includeNegativeValues ? ` ` : `  AND NVL(pa.detail_mv, 0) >= 1 `;

    sql:ParameterizedQuery queryPart3 =
        `GROUP BY pa.portfolio_id, pa.category, pa.category_code`;

    return sql:queryConcat(queryPart1, queryPart2, queryPart3);
}
