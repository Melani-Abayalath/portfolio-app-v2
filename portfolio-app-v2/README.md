# portfolio-app-v2

A load testing service that mimics the **new** `account-data-api` codebase — specifically the `relationshipAssetAllocation` endpoint — including the impersonation and JWT processing logic introduced in the new code.

## What Is Different from portfolio-app (v1)

| Aspect | v1 (old code replica) | v2 (new code replica) |
|---|---|---|
| Impersonation logic | Not present | Present — reads `x-bt-impersonate` header |
| JWT processing | Not present | Present — mocked `jwtProcessor:getUserId` |
| `allowImpersonation` configurable | Not present | Present — defaults to `true` |
| `x-jwt-assertion` header | Not read | Read and processed |
| DB schema | Same | Same (`perf_test`) |
| Endpoint | Same | Same (`portfolioAllocationSummary`) |
| Ballerina version | 2201.12.2 | 2201.12.2 |

## Note on JWT Processor Mock

The new `account-data-api` uses an internal package `bgic/bt.commons.jwt.processor`
to extract a user ID from the JWT assertion header. That package is not available here.

The mock (`mockGetUserId`) replicates the structural behaviour:
- Receives the `x-jwt-assertion` header string
- Checks if it is a valid JWT (three dot-separated segments)
- Returns a placeholder user ID or empty string

Based on nanosecond log analysis from the 2026-04-20 load test, the real
`jwtProcessor:getUserId` call completed in **0.826ms**. The mock adds comparable
negligible overhead.

## Configure the Service

Create `service/Config.toml` (not committed — contains credentials):

```toml
[portfolio_allocation_api_v2.data.redshiftConfig]
jdbcUrl            = "jdbc:redshift://<host>:5439/<database>"
user               = "<username>"
password           = "<password>"
maxOpenConnections = 20
minIdleConnections = 5

[portfolio_allocation_api_v2]
port                   = 9090
enableGraphiql         = false
graphqlListenerTimeout = 180.0
allowImpersonation     = true
```

## Run Locally

```bash
cd service
bal run
```

## GraphQL Query

Same as v1:

```graphql
query PortfolioAllocationSummary($portfolioId: String!, $includeNegativeValues: Boolean) {
  portfolioAllocationSummary(input: { portfolioId: $portfolioId, includeNegativeValues: $includeNegativeValues }) {
    portfolioId
    totalValue
    segments {
      name
      code
      marketValue
      percentage
    }
  }
}
```

## Load Test Headers

When testing via Choreo, the following headers can be added to JMeter to
trigger the impersonation path (matching what happens in production):

| Header | Value | Effect |
|---|---|---|
| `x-bt-impersonate` | Any user ID string | Triggers impersonation block — logs "userId is set to impersonatedUser" |
| `x-jwt-assertion` | Any JWT string | Triggers JWT processing block — logs "From JWT assertion, userId is empty" |
| Neither header | — | Both blocks skipped — userId remains empty string |

To replicate the exact behaviour seen in the 2026-04-20 load test logs, include
both headers in JMeter requests.
