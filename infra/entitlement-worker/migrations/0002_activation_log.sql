-- Append-only history of device-slot claims (one row per REPLACE of a
-- *different* current holder; empty-slot first claims and idempotent
-- same-device re-redeems are not logged). Serves two purposes: the windowed
-- abuse bound on beta/afdian re-activation, and console visibility (who held
-- which slot when).
-- Residual limitation, stated honestly: device_id is per-install, so the
-- worker cannot recognize a reinstalled same physical device — a device that
-- reinstalls more than ACTIVATION_CAP times within the window still needs a
-- manual reset (delete its activation_log rows).
CREATE TABLE activation_log (
  entitlement_id INTEGER NOT NULL,
  device_class   TEXT    NOT NULL,
  device_id      TEXT    NOT NULL,
  activated_at   INTEGER NOT NULL
);
CREATE INDEX idx_activation_log_slot
  ON activation_log (entitlement_id, device_class, activated_at);
