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

/// Generous ceiling for the largest legitimate body (a Google id_token plus a
/// Play purchase token is a couple of KB).
const MAX_BODY_BYTES = 32 * 1024;

/// Sent on every response. The API carries entitlement tokens and Google
/// id_tokens, and the custom domain answers plain HTTP as well as HTTPS — so
/// without this a client that ever resolves the bare host over http:// keeps
/// doing it. Two years, subdomains included; no `preload` since that is a
/// one-way commitment for the whole apex.
const SECURITY_HEADERS = {
  'content-type': 'application/json',
  'strict-transport-security': 'max-age=63072000; includeSubDomains',
} as const;

function toResponse(res: Res): Response {
  if (res.body === null) {
    return new Response(null, {
      status: res.status,
      headers: {
        'strict-transport-security': SECURITY_HEADERS['strict-transport-security'],
      },
    });
  }
  return new Response(JSON.stringify(res.body), {
    status: res.status,
    headers: SECURITY_HEADERS,
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
      // Every body here is a handful of tokens and ids — a few hundred bytes.
      // Bound it before parsing: the field checks downstream only run *after*
      // JSON.parse has already walked whatever arrived, so an unauthenticated
      // caller could otherwise spend the isolate's CPU on megabytes of it.
      // Content-Length catches the ordinary case cheaply; the text length
      // catches a chunked body that never declares one.
      const declared = Number(request.headers.get('content-length') ?? '0');
      if (declared > MAX_BODY_BYTES) {
        return toResponse({ status: 413, body: { error: 'body_too_large' } });
      }
      const raw = await request.text();
      if (raw.length > MAX_BODY_BYTES) {
        return toResponse({ status: 413, body: { error: 'body_too_large' } });
      }
      body = JSON.parse(raw);
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
