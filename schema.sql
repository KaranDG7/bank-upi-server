-- ═══════════════════════════════════════════════════════════
-- UPI FRAUD DETECTION SYSTEM — DATABASE SCHEMA
-- Run this in PostgreSQL before starting the server
-- ═══════════════════════════════════════════════════════════

-- ── TABLE 1: Users (mobile + PIN login) ──────────────────────
CREATE TABLE IF NOT EXISTS users (
    id              BIGSERIAL PRIMARY KEY,
    name            VARCHAR(200) NOT NULL,
    mobile_number   VARCHAR(15)  UNIQUE NOT NULL,
    pin_hash        VARCHAR(255) NOT NULL,
    email           VARCHAR(200),
    is_active       BOOLEAN DEFAULT true,
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW()
);

-- ── TABLE 2: Personal Accounts (Savings / Current) ───────────
-- For individual users — NOT used in merchant activity
CREATE TABLE IF NOT EXISTS personal_accounts (
    id                      BIGSERIAL PRIMARY KEY,
    user_id                 BIGINT REFERENCES users(id) ON DELETE CASCADE,

    -- Core account fields
    account_number          VARCHAR(20)  UNIQUE NOT NULL,
    account_type            VARCHAR(20)  DEFAULT 'savings', -- 'savings' | 'current'
    bank_name               VARCHAR(100),
    bank_handle             VARCHAR(50),  -- okaxis, ybl, icici etc.
    vpa_address             VARCHAR(200) UNIQUE,
    ifsc_code               VARCHAR(11),
    ifsc_valid              BOOLEAN DEFAULT true,
    balance                 DECIMAL(15,2) DEFAULT 0.00,

    -- Identity / KYC fields
    kyc_status              VARCHAR(20) DEFAULT 'none', -- 'none'|'partial'|'full'
    mobile_linked           BOOLEAN DEFAULT true,
    aadhaar_linked          BOOLEAN DEFAULT false,
    pan_linked              BOOLEAN DEFAULT false,

    -- Fraud detection fields (from our factor analysis)
    total_transactions      INT DEFAULT 0,
    avg_receive_amount      DECIMAL(12,2) DEFAULT 0.00,
    collect_request_ratio   DECIMAL(5,4) DEFAULT 0.0000,
    dormant_days            INT DEFAULT 0,
    report_count            INT DEFAULT 0,
    dispute_count           INT DEFAULT 0,
    community_positive      INT DEFAULT 0,
    txn_last_24h            INT DEFAULT 0,
    txn_last_7d             INT DEFAULT 0,
    avg_daily_txn           DECIMAL(8,2) DEFAULT 0.00,
    confirmed_fraud         BOOLEAN DEFAULT false,

    is_active               BOOLEAN DEFAULT true,
    created_at              TIMESTAMP DEFAULT NOW(),
    updated_at              TIMESTAMP DEFAULT NOW()
);

-- ── TABLE 3: Merchant / Business Accounts ────────────────────
-- Extra fields: merchant ID, category, GST, business type
CREATE TABLE IF NOT EXISTS merchant_accounts (
    id                      BIGSERIAL PRIMARY KEY,
    user_id                 BIGINT REFERENCES users(id) ON DELETE CASCADE,

    -- Core account fields
    account_number          VARCHAR(20)  UNIQUE NOT NULL,
    business_name           VARCHAR(200),
    bank_name               VARCHAR(100),
    bank_handle             VARCHAR(50),
    vpa_address             VARCHAR(200) UNIQUE,
    ifsc_code               VARCHAR(11),
    ifsc_valid              BOOLEAN DEFAULT true,
    balance                 DECIMAL(15,2) DEFAULT 0.00,

    -- Merchant-specific fields
    merchant_id             VARCHAR(50) UNIQUE,
    merchant_category       VARCHAR(10),  -- MCC code e.g. '5411'
    merchant_category_name  VARCHAR(100), -- e.g. 'Grocery Store'
    business_type           VARCHAR(50),  -- 'sole_proprietor'|'partnership'|'pvt_ltd'
    gst_number              VARCHAR(20),
    registered_address      TEXT,

    -- Identity / KYC
    kyc_status              VARCHAR(20) DEFAULT 'none',
    mobile_linked           BOOLEAN DEFAULT true,
    pan_linked              BOOLEAN DEFAULT false,
    gst_verified            BOOLEAN DEFAULT false,

    -- Fraud detection fields
    total_transactions      INT DEFAULT 0,
    avg_receive_amount      DECIMAL(12,2) DEFAULT 0.00,
    collect_request_ratio   DECIMAL(5,4) DEFAULT 0.0000,
    report_count            INT DEFAULT 0,
    dispute_count           INT DEFAULT 0,
    community_positive      INT DEFAULT 0,
    txn_last_24h            INT DEFAULT 0,
    txn_last_7d             INT DEFAULT 0,
    avg_daily_txn           DECIMAL(8,2) DEFAULT 0.00,
    confirmed_fraud         BOOLEAN DEFAULT false,

    is_active               BOOLEAN DEFAULT true,
    created_at              TIMESTAMP DEFAULT NOW(),
    updated_at              TIMESTAMP DEFAULT NOW()
);

-- ── TABLE 4: Transactions ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS transactions (
    id                  BIGSERIAL PRIMARY KEY,
    account_id          BIGINT NOT NULL,
    account_table       VARCHAR(20) NOT NULL, -- 'personal' | 'merchant'

    -- UPI reference
    txn_ref             VARCHAR(50) UNIQUE DEFAULT ('TXN' || LPAD(floor(random()*1000000000)::text, 12, '0')),
    upi_ref             VARCHAR(50),

    -- Transaction details
    txn_type            VARCHAR(10) NOT NULL, -- 'DEBIT' | 'CREDIT'
    amount              DECIMAL(12,2) NOT NULL,
    balance_after       DECIMAL(12,2),

    -- Counterparty
    counterparty_name   VARCHAR(200),
    counterparty_vpa    VARCHAR(200),
    counterparty_bank   VARCHAR(100),

    -- Metadata
    note                TEXT,
    status              VARCHAR(20) DEFAULT 'SUCCESS', -- 'SUCCESS'|'FAILED'|'PENDING'
    is_collect_request  BOOLEAN DEFAULT false,
    category            VARCHAR(50), -- 'food'|'rent'|'shopping'|'transfer' etc.

    -- Fraud signals at time of transaction
    fraud_score         INT,
    fraud_verdict       VARCHAR(20),
    user_was_warned     BOOLEAN DEFAULT false,
    user_overrode_warn  BOOLEAN DEFAULT false,

    created_at          TIMESTAMP DEFAULT NOW()
);

-- ── TABLE 5: Fraud Reports ────────────────────────────────────
CREATE TABLE IF NOT EXISTS fraud_reports (
    id              BIGSERIAL PRIMARY KEY,
    vpa_address     VARCHAR(200) NOT NULL,
    reported_by     BIGINT REFERENCES users(id),
    fraud_type      VARCHAR(50),
    -- 'impersonation'|'collect_scam'|'non_delivery'|'other'
    amount_lost     DECIMAL(12,2),
    description     TEXT,
    verified        BOOLEAN DEFAULT false,
    created_at      TIMESTAMP DEFAULT NOW()
);

-- ── TABLE 6: Known Bank Handles ──────────────────────────────
CREATE TABLE IF NOT EXISTS bank_handles (
    handle          VARCHAR(50) PRIMARY KEY,
    bank_name       VARCHAR(100),
    bank_type       VARCHAR(50), -- 'scheduled'|'payments_bank'|'cooperative'
    is_valid        BOOLEAN DEFAULT true,
    risk_level      VARCHAR(10) DEFAULT 'low'
);

-- ── SEED: Bank Handles ────────────────────────────────────────
INSERT INTO bank_handles (handle, bank_name, bank_type, risk_level) VALUES
('okaxis',      'Axis Bank',              'scheduled',    'low'),
('axisbank',    'Axis Bank',              'scheduled',    'low'),
('ybl',         'Yes Bank',               'scheduled',    'low'),
('yesbankltd',  'Yes Bank',               'scheduled',    'low'),
('icici',       'ICICI Bank',             'scheduled',    'low'),
('okicici',     'ICICI Bank',             'scheduled',    'low'),
('okhdfc',      'HDFC Bank',              'scheduled',    'low'),
('okhdfcbank',  'HDFC Bank',              'scheduled',    'low'),
('oksbi',       'State Bank of India',    'scheduled',    'low'),
('sbi',         'State Bank of India',    'scheduled',    'low'),
('paytm',       'Paytm Payments Bank',    'payments_bank','low'),
('apl',         'Airtel Payments Bank',   'payments_bank','low'),
('ibl',         'IndusInd Bank',          'scheduled',    'low'),
('kotak',       'Kotak Mahindra Bank',    'scheduled',    'low'),
('upi',         'NPCI Generic',           'generic',      'medium'),
('waaxis',      'Axis Bank (WhatsApp)',   'scheduled',    'low'),
('wahdfcbank',  'HDFC Bank (WhatsApp)',   'scheduled',    'low')
ON CONFLICT DO NOTHING;

-- ── INDEXES for performance ───────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_personal_vpa    ON personal_accounts(vpa_address);
CREATE INDEX IF NOT EXISTS idx_merchant_vpa    ON merchant_accounts(vpa_address);
CREATE INDEX IF NOT EXISTS idx_txn_account     ON transactions(account_id, account_table);
CREATE INDEX IF NOT EXISTS idx_txn_created     ON transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reports_vpa     ON fraud_reports(vpa_address);
CREATE INDEX IF NOT EXISTS idx_users_mobile    ON users(mobile_number);
