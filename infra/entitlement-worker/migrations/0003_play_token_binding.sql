-- A Play purchase token must belong to exactly one entitlement.
--
-- Before this, /v1/play/verify validated the caller's Google id_token and the
-- purchase token *independently* and then wrote the result under the id_token's
-- `sub`. Nothing tied the two together and nothing stopped a second `sub` from
-- presenting the same token, so one real subscriber could hand their token to
-- any number of people and each would be granted their own Pro entitlement.
--
-- The index is the enforcement point, not the application code: two concurrent
-- verifies with the same token cannot both pass a read-then-write check, but
-- they cannot both satisfy a unique index. logic.ts turns the resulting
-- constraint failure into 403 `purchase_token_bound`.
--
-- Partial (WHERE NOT NULL) because every non-Play channel leaves the column
-- NULL, and SQLite would otherwise treat only one NULL as allowed... it would
-- not — NULLs are distinct in a SQLite unique index — but stating the intent
-- keeps the index small and its purpose obvious.
CREATE UNIQUE INDEX idx_entitlements_play_token
  ON entitlements (play_purchase_token)
  WHERE play_purchase_token IS NOT NULL;
