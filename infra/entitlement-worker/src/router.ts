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
