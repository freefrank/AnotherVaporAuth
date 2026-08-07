import { WorkerMailer } from "worker-mailer";

// Not a secret (the app is open source) — it only keeps generic scanners and
// accidental traffic off the endpoint. Real abuse is handled by size caps and,
// if it ever matters, WAF rate rules on the custom domain.
const CLIENT_TOKEN = "ava-feedback-v1";

const MAX_MESSAGE = 4000;
const MAX_CONTACT = 200;
const MAX_META = 300;
const MAX_LOG = 16000;
const MAX_BODY = 64 * 1024; // whole request, checked before JSON.parse

function bad(status, msg) {
  return new Response(JSON.stringify({ ok: false, error: msg }), {
    status,
    headers: { "content-type": "application/json" },
  });
}

// Two sanitizers, because one is not enough. The comment that used to sit
// here claimed `clean` stopped SMTP header injection — it did not: it keeps
// \n on purpose, and `meta` goes straight into the Subject.
//
/// For the multi-line parts of the mail body. Deliberately keeps \n (0x0A)
/// and \t (0x09) — the message and the debug log are meant to have them.
/// Note the range starts at 0x0B, so \r (0x0D) IS stripped: CRLF in the body
/// would otherwise let a crafted message forge the transport's line endings.
function clean(s) {
  // eslint-disable-next-line no-control-regex
  return s.replace(/[\x00-\x08\x0B-\x1F\x7F]/g, "");
}

/// For anything that ends up on a single line — above all a mail *header*.
/// `clean` alone is not enough there: it preserves \n, and `meta` is
/// interpolated straight into the Subject, so "x\nBcc: …" would have been
/// handed to the SMTP layer as a header the user chose. Tabs go too, since
/// leading whitespace is how header folding continues a line.
function cleanLine(s) {
  return clean(s).replace(/[\t\n]+/g, " ").trim();
}

// --- Rate limiting (per client IP) -------------------------------------
// The client token in this file is not a secret (see above), so anyone who
// copies it can script requests. This is the abuse brake: cap how often a
// single IP can trigger an actual SMTP send.
//
// Backed by Workers KV (binding `RL`, see wrangler.toml) so the limit is
// shared across all Worker instances/regions, not per-instance memory.
// KV is eventually consistent and has no atomic increment, so a burst of
// truly simultaneous requests from the same IP could each read the same
// stale counter and all slip through — that's an accepted trade-off for a
// soft abuse deterrent, not a hard security boundary (the token + size caps
// still apply on top).
//
// Fail-open on KV errors: if the store itself is down/misconfigured, we log
// and let the request continue rather than break legitimate feedback
// delivery because of an unrelated infra hiccup. This does mean rate
// limiting is best-effort, not guaranteed — acceptable here since email
// abuse (reputation damage) is the concern, not a resource-exhaustion DoS.
const RATE_LIMIT_PER_MINUTE = 3; // sends allowed per IP per rolling minute bucket
const RATE_LIMIT_PER_DAY = 20; // sends allowed per IP per rolling day bucket
const MINUTE_BUCKET_TTL = 120; // seconds; > 60 so a slow read can't undercount near the edge
const DAY_BUCKET_TTL = 60 * 60 * 25; // seconds; > 1 day for the same reason

async function isRateLimited(env, ip) {
  if (!env.RL || !ip || ip === "unknown") {
    // No KV bound (e.g. local dev without the namespace configured yet) or
    // no way to identify the caller — nothing to key the limit on.
    return false;
  }

  const now = Date.now();
  const minuteKey = `m:${ip}:${Math.floor(now / 60000)}`;
  const dayKey = `d:${ip}:${Math.floor(now / 86400000)}`;

  try {
    const [minuteRaw, dayRaw] = await Promise.all([
      env.RL.get(minuteKey),
      env.RL.get(dayKey),
    ]);
    const minuteCount = parseInt(minuteRaw, 10) || 0;
    const dayCount = parseInt(dayRaw, 10) || 0;

    if (minuteCount >= RATE_LIMIT_PER_MINUTE || dayCount >= RATE_LIMIT_PER_DAY) {
      return true;
    }

    // Best-effort increment (not atomic — see comment above).
    await Promise.all([
      env.RL.put(minuteKey, String(minuteCount + 1), {
        expirationTtl: MINUTE_BUCKET_TTL,
      }),
      env.RL.put(dayKey, String(dayCount + 1), { expirationTtl: DAY_BUCKET_TTL }),
    ]);
    return false;
  } catch (e) {
    console.error("rate limit store error:", e && e.stack ? e.stack : e);
    return false; // fail-open; see comment above
  }
}

export default {
  async fetch(request, env) {
    try {
      return await handle(request, env);
    } catch (e) {
      // Log the detail server-side; never leak internal/provider error text
      // to the client (it only helps an attacker tune abuse).
      console.error("feedback worker error:", e && e.stack ? e.stack : e);
      return bad(500, "internal error");
    }
  },
};

async function handle(request, env) {
  if (request.method !== "POST") return bad(405, "POST only");
  if (request.headers.get("x-ava-client") !== CLIENT_TOKEN) {
    return bad(403, "unknown client");
  }

  const ip = request.headers.get("cf-connecting-ip") ?? "unknown";
  if (await isRateLimited(env, ip)) {
    return bad(429, "too many requests");
  }

  // Bound the body before parsing. The per-field caps below only apply once
  // JSON.parse has already walked whatever arrived, so without this an
  // unauthenticated caller could hand the isolate megabytes to chew on.
  // The sum of the field limits is ~20 KB; 64 KB leaves room for JSON
  // overhead and multi-byte text.
  const declaredLen = Number(request.headers.get("content-length") ?? "0");
  if (declaredLen > MAX_BODY) return bad(413, "too long");
  let body;
  try {
    const raw = await request.text();
    if (raw.length > MAX_BODY) return bad(413, "too long");
    body = JSON.parse(raw);
  } catch {
    return bad(400, "invalid JSON");
  }

  const message = clean((body.message ?? "").toString().trim());
  // Single-line by nature, and `meta` reaches the Subject header — both must
  // be header-safe, not merely control-character-free.
  const contact = cleanLine((body.contact ?? "").toString());
  const meta = cleanLine((body.meta ?? "").toString()); // "AVA 0.65.2 · android · zh"
  const log = clean((body.log ?? "").toString()); // opt-in in-app debug log tail
  if (!message) return bad(400, "empty message");
  if (
    message.length > MAX_MESSAGE ||
    contact.length > MAX_CONTACT ||
    meta.length > MAX_META ||
    log.length > MAX_LOG
  ) {
    return bad(413, "too long");
  }

  const text = [
    message,
    "",
    "---",
    `meta:    ${meta || "-"}`,
    `contact: ${contact || "-"}`,
    `ip:      ${ip}`,
    `time:    ${new Date().toISOString()}`,
    ...(log ? ["", `--- debug log (${log.length} chars) ---`, log] : []),
  ].join("\n");

  try {
    const mailer = await WorkerMailer.connect({
      host: env.SMTP_HOST,
      port: Number(env.SMTP_PORT),
      secure: Number(env.SMTP_PORT) === 465,
      startTls: Number(env.SMTP_PORT) !== 465,
      credentials: { username: env.SMTP_USER, password: env.SMTP_PASS },
      authType: "plain",
    });
    await mailer.send({
      from: { name: "AVA Feedback", email: env.SMTP_FROM },
      to: { email: env.MAIL_TO },
      subject: `[AVA feedback] ${meta || "no meta"}`,
      text,
    });
  } catch (e) {
    console.error("feedback send failed:", e && e.stack ? e.stack : e);
    return bad(502, "send failed");
  }

  return new Response(JSON.stringify({ ok: true }), {
    headers: { "content-type": "application/json" },
  });
}
