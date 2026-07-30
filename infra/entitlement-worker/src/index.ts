// Worker entrypoint: builds the production dependency graph (D1 store, real
// Google/Afdian/AdMob clients, KV-backed config) and hands requests to the
// router. All business logic lives in logic.ts behind injected deps.

import { createAdmob } from './admob';
import { createAfdian } from './afdian';
import type { Env } from './env';
import { createGoogle } from './google';
import { createTokenService, importSigningKeys, type TokenService } from './jwt';
import type { Deps } from './logic';
import { route } from './router';
import { D1Store } from './store';

const DEFAULT_VIP_DAYS = 3;
const DEFAULT_ACTIVATION_WINDOW_DAYS = 90;
const DEFAULT_ACTIVATION_CAP = 5;
const SSV_TXN_TTL_SECONDS = 7 * 86400;

/** Lazily imports the signing key once per isolate. */
function lazyTokenService(secret: string): TokenService {
  let p: Promise<TokenService> | null = null;
  const get = () => (p ??= importSigningKeys(secret).then(createTokenService));
  return {
    sign: async (claims) => (await get()).sign(claims),
    verify: async (raw) => (await get()).verify(raw),
  };
}

let cachedDeps: Deps | null = null;

function buildDeps(env: Env): Deps {
  if (cachedDeps) return cachedDeps;
  const now = () => Math.floor(Date.now() / 1000);
  // KV-tunable positive integers; anything unset/garbage falls back.
  const kvNumber = async (key: string, fallback: number): Promise<number> => {
    const v = Number(await env.CONFIG.get(key));
    return Number.isFinite(v) && v > 0 ? v : fallback;
  };
  cachedDeps = {
    store: new D1Store(env.DB),
    tokens: lazyTokenService(env.ENTITLEMENT_SIGNING_KEY),
    google: createGoogle({
      saEmail: env.GOOGLE_SA_EMAIL,
      saKey: env.GOOGLE_SA_KEY,
      packageName: env.PLAY_PACKAGE_NAME,
      clientId: env.GOOGLE_CLIENT_ID,
    }),
    afdian: createAfdian({ userId: env.AFDIAN_USER_ID, token: env.AFDIAN_TOKEN }),
    admob: createAdmob({ kv: env.CONFIG }),
    config: {
      afdianPlanId: () => env.AFDIAN_PLAN_ID,
      vipDays: () => kvNumber('VIP_DAYS', DEFAULT_VIP_DAYS),
      activationWindowDays: () =>
        kvNumber('ACTIVATION_WINDOW_DAYS', DEFAULT_ACTIVATION_WINDOW_DAYS),
      activationCap: () => kvNumber('ACTIVATION_CAP', DEFAULT_ACTIVATION_CAP),
    },
    replay: {
      async seenTransaction(id: string): Promise<boolean> {
        const key = `ssv_txn:${id}`;
        if (await env.CONFIG.get(key)) return true;
        await env.CONFIG.put(key, '1', { expirationTtl: SSV_TXN_TTL_SECONDS });
        return false;
      },
    },
    rateLimit: {
      async allow(key: string): Promise<boolean> {
        // Unlike the aud check in google.ts, this one fails OPEN when the
        // binding is missing: a broken limiter must not lock paying users
        // out of redeeming. The trade-off is deliberate — losing a brake
        // costs abuse, losing an auth check costs correctness — so shout
        // about it in the log instead of degrading silently.
        if (!env.REDEEM_LIMITER) {
          console.error('REDEEM_LIMITER binding missing — redeem endpoints unthrottled');
          return true;
        }
        const { success } = await env.REDEEM_LIMITER.limit({ key });
        return success;
      },
    },
    now,
  };
  return cachedDeps;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    try {
      return await route(request, buildDeps(env));
    } catch (e) {
      console.error('unhandled', e instanceof Error ? e.stack : e);
      return new Response(JSON.stringify({ error: 'internal' }), {
        status: 500,
        headers: { 'content-type': 'application/json' },
      });
    }
  },
} satisfies ExportedHandler<Env>;
