export interface Env {
  DB: D1Database;
  CONFIG: KVNamespace;

  // Secrets (wrangler secret put …):
  /** base64 PKCS#8 Ed25519 private key: `openssl pkey -outform DER | base64 -w0`. */
  ENTITLEMENT_SIGNING_KEY: string;
  /** Afdian open-platform user_id. */
  AFDIAN_USER_ID: string;
  /** Afdian open-platform API token. */
  AFDIAN_TOKEN: string;
  /** plan_id of the AVA Pro plan on Afdian. */
  AFDIAN_PLAN_ID: string;
  /** Play service-account client_email. */
  GOOGLE_SA_EMAIL: string;
  /** Play service-account private key (PEM or bare base64 PKCS#8). */
  GOOGLE_SA_KEY: string;
  /** e.g. pro.dotslash.ava */
  PLAY_PACKAGE_NAME: string;
  /** The app's Web OAuth client id. Required — Google id_token `aud` is
   * pinned to it, and verification fails outright when it is unset. */
  GOOGLE_CLIENT_ID: string;

  /** Per-IP brake on the secret-guessing redeem endpoints (wrangler.jsonc
   * `ratelimits`). */
  REDEEM_LIMITER?: RateLimit;
}
