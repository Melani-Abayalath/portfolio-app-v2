-- ============================================================
-- Performance test seed data for portfolio-allocation-api-v2
-- Schema:  perf_test
-- Tables:  portfolio_hierarchy (1 row)
--          portfolio_allocation (10 rows)
--
-- One fixed portfolio ID: PA-2000031588
-- Mirrors the single fixed input used in the customer load test
-- (relationshipNo: 2000031588 in account-data-api)
--
-- All 50 virtual users in JMeter send the same portfolioId
-- to eliminate data variability across requests.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS perf_test;

DROP TABLE IF EXISTS perf_test.portfolio_allocation;
DROP TABLE IF EXISTS perf_test.portfolio_hierarchy;

CREATE TABLE perf_test.portfolio_hierarchy (
    subaccount_no     VARCHAR(20)  NOT NULL,
    portfolio_id      VARCHAR(20)  NOT NULL,
    subaccount_active CHAR(1)      NOT NULL DEFAULT 'Y',
    PRIMARY KEY (subaccount_no)
);

CREATE TABLE perf_test.portfolio_allocation (
    portfolio_id   VARCHAR(20)    NOT NULL,
    entity_no      VARCHAR(20)    NOT NULL,
    as_of_date     DATE           NULL,
    category       VARCHAR(100)   NOT NULL,
    category_code  VARCHAR(10)    NOT NULL,
    detail_mv      DECIMAL(18,2)  NOT NULL DEFAULT 0.00
);

-- ============================================================
-- portfolio_hierarchy — single subaccount for PA-2000031588
-- ============================================================
INSERT INTO perf_test.portfolio_hierarchy
    (subaccount_no, portfolio_id, subaccount_active)
VALUES
    ('SUB-PA-031588', 'PA-2000031588', 'Y');

-- ============================================================
-- portfolio_allocation — 10 asset categories for PA-2000031588
-- Categories mirror real asset class structure from account-data-api
-- as_of_date IS NULL on all rows (matches WHERE pa.as_of_date IS NULL)
-- ============================================================
INSERT INTO perf_test.portfolio_allocation
    (portfolio_id, entity_no, as_of_date, category, category_code, detail_mv)
VALUES
    ('PA-2000031588', 'SUB-PA-031588', NULL, 'Domestic Equities',                '01',  482340.75),
    ('PA-2000031588', 'SUB-PA-031588', NULL, 'International Equities',            '02',  214500.50),
    ('PA-2000031588', 'SUB-PA-031588', NULL, 'Fixed Income - Investment Grade',   '03',  310000.00),
    ('PA-2000031588', 'SUB-PA-031588', NULL, 'Fixed Income - High Yield',         '04',   95000.25),
    ('PA-2000031588', 'SUB-PA-031588', NULL, 'Cash & Cash Equivalents',           '05',   52100.00),
    ('PA-2000031588', 'SUB-PA-031588', NULL, 'Real Assets',                       '06',  138000.00),
    ('PA-2000031588', 'SUB-PA-031588', NULL, 'Private Equity',                    '07',  220000.00),
    ('PA-2000031588', 'SUB-PA-031588', NULL, 'Hedge Funds',                       '08',  175000.00),
    ('PA-2000031588', 'SUB-PA-031588', NULL, 'Commodities',                       '09',   43000.00),
    ('PA-2000031588', 'SUB-PA-031588', NULL, 'Short-Term Investments',            '10',   28500.00);

-- ============================================================
-- Verify
-- SELECT COUNT(*) FROM perf_test.portfolio_hierarchy;  -- expected: 1
-- SELECT COUNT(*) FROM perf_test.portfolio_allocation;  -- expected: 10
-- ============================================================
