-- AVA entitlement service — initial schema.

CREATE TABLE entitlements (
  id INTEGER PRIMARY KEY,
  channel TEXT NOT NULL,             -- 'play' | 'afdian' | 'beta'
  subject TEXT NOT NULL,             -- Google sub / Afdian user_id / beta code / device_id (vip)
  tier TEXT NOT NULL DEFAULT 'pro',  -- 'pro' | 'vip'
  pro_until INTEGER NOT NULL,        -- epoch seconds; 0 = lifetime
  revoked INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  -- Kept so /v1/token/refresh can re-query the Play subscription after
  -- pro_until lapses (the refresh request carries no purchase token).
  play_purchase_token TEXT,
  UNIQUE(channel, subject)
);

-- One slot per (entitlement, device class): activating a new device of the
-- same class REPLACEs the row; the kicked device's next refresh gets 403.
CREATE TABLE devices (
  entitlement_id INTEGER NOT NULL,
  device_class TEXT NOT NULL,        -- 'android' | 'windows' | 'linux' | 'macos'
  device_id TEXT NOT NULL,
  activated_at INTEGER NOT NULL,
  PRIMARY KEY (entitlement_id, device_class)
);

CREATE TABLE afdian_orders (
  out_trade_no TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  plan_id TEXT NOT NULL,
  paid_at INTEGER NOT NULL,
  entitlement_id INTEGER             -- NULL when the webhook arrives before in-app redeem
);

CREATE TABLE beta_testers (
  code TEXT PRIMARY KEY,
  email TEXT,
  redeemed_by TEXT                   -- device_id of the first redeemer; NULL = unredeemed
);
