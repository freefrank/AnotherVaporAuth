-- Append-only history of device-slot claims (one row per actual device
-- change; idempotent same-device re-redeems are not logged). Serves two
-- purposes: the windowed abuse bound on beta/afdian re-activation, and
-- console visibility (who held which slot when).
CREATE TABLE activation_log (
  entitlement_id INTEGER NOT NULL,
  device_class   TEXT    NOT NULL,
  device_id      TEXT    NOT NULL,
  activated_at   INTEGER NOT NULL
);
CREATE INDEX idx_activation_log_slot
  ON activation_log (entitlement_id, device_class, activated_at);
