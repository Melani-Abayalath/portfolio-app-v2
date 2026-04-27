// ── Correlation / tracing headers ──────────────────────────────────────────
public const X_BT_CORRELATION_ID = "x-bt-correlation-id";
public const X_REQUEST_ID        = "x-request-id";
public const CLIENT               = "client";

// ── Context keys ────────────────────────────────────────────────────────────
public const CORRELATION_ID = "correlationId";
public const REQUEST_ID     = "requestId";

// ── Impersonation headers (new code) ────────────────────────────────────────
// Matches X_IMPERSONATION and X_JWT from new account-data-api server.bal
public const X_IMPERSONATION = "x-bt-impersonate";
public const X_JWT            = "x-jwt-assertion";
public const X_USERID         = "userId";
