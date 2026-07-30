// Plain fetch-handler routing — a switch, no framework.

import type { Deps, Res } from './logic';
import {
  handleAdmobSsv,
  handleAfdianRedeem,
  handleAfdianWebhook,
  handleBetaRedeem,
  handleEntitlementStatus,
  handlePlayVerify,
  handleRefresh,
  handleVipClaim,
} from './logic';

// Endpoints whose request body carries a *guessable* secret, so an attacker
// gains from volume: a beta code is 32 bits of entropy and buys lifetime Pro,
// an Afdian out_trade_no is a semi-sequential order number. The token-bearing
// endpoints are deliberately absent — an Ed25519 signature is not guessable,
// and throttling refresh would break legitimate clients.
//
// Note this brake is per Cloudflare location, so a caller spread across many
// colos gets a correspondingly larger budget. It raises the cost of a naive
// script; it is not a defence against a distributed attacker.
const RATE_LIMITED = new Set(['POST /v1/beta/redeem', 'POST /v1/afdian/redeem']);

function toResponse(res: Res): Response {
  if (res.body === null) return new Response(null, { status: res.status });
  return new Response(JSON.stringify(res.body), {
    status: res.status,
    headers: { 'content-type': 'application/json' },
  });
}

export async function route(request: Request, deps: Deps): Promise<Response> {
  const url = new URL(request.url);
  const key = `${request.method} ${url.pathname}`;

  if (key === 'GET /v1/admob/ssv') return toResponse(await handleAdmobSsv(url, deps));

  if (RATE_LIMITED.has(key)) {
    const ip = request.headers.get('cf-connecting-ip') ?? 'unknown';
    if (!(await deps.rateLimit.allow(`redeem:${ip}`))) {
      return toResponse({ status: 429, body: { error: 'rate_limited' } });
    }
  }

  const post = async (handler: (body: unknown, deps: Deps) => Promise<Res>): Promise<Response> => {
    let body: unknown;
    try {
      body = await request.json();
    } catch {
      return toResponse({ status: 400, body: { error: 'bad_request' } });
    }
    return toResponse(await handler(body, deps));
  };

  switch (key) {
    case 'POST /v1/token/refresh':
      return post(handleRefresh);
    case 'POST /v1/play/verify':
      return post(handlePlayVerify);
    case 'POST /v1/afdian/redeem':
      return post(handleAfdianRedeem);
    case 'POST /v1/afdian/webhook':
      return post(handleAfdianWebhook);
    case 'POST /v1/beta/redeem':
      return post(handleBetaRedeem);
    case 'POST /v1/entitlement/status':
      return post(handleEntitlementStatus);
    case 'POST /v1/vip/claim':
      return post(handleVipClaim);
    default:
      return toResponse({ status: 404, body: { error: 'not_found' } });
  }
}
