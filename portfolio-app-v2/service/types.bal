// ── Request input ────────────────────────────────────────────────────────────
public type PortfolioAllocationInput record {|
    string portfolioId;
    boolean? includeNegativeValues;
|};

// ── Response types ───────────────────────────────────────────────────────────
public type PortfolioAllocationResult record {|
    string portfolioId;
    decimal totalValue;
    AllocationSegment[] segments;
|};

public type AllocationSegment record {
    string name;
    string code;
    decimal marketValue;
    decimal percentage;
};

// ── Logging context ──────────────────────────────────────────────────────────
// Matches constructLoggingContext in new account-data-api utils.bal
public type LoggingContext record {|
    string correlationId;
    string requestId;
    string 'client;
|};
