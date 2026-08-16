-- Masked-hint support for purchase_token_bound (multi-account phones):
-- remember the email of the Google account an entitlement is bound to, so
-- the refusal can say "bound to a•••@gmail.com" instead of a dead end.
-- Nullable: rows from before this migration simply produce a hint-less error.
ALTER TABLE entitlements ADD COLUMN subject_email TEXT;
