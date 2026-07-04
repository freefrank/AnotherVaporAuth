import { WorkerMailer } from "worker-mailer";

// Not a secret (the app is open source) — it only keeps generic scanners and
// accidental traffic off the endpoint. Real abuse is handled by size caps and,
// if it ever matters, WAF rate rules on the custom domain.
const CLIENT_TOKEN = "ava-feedback-v1";

const MAX_MESSAGE = 4000;
const MAX_CONTACT = 200;
const MAX_META = 300;
const MAX_LOG = 16000;

function bad(status, msg) {
  return new Response(JSON.stringify({ ok: false, error: msg }), {
    status,
    headers: { "content-type": "application/json" },
  });
}

// Strip control characters (except tab/newline) so a crafted field can't
// inject SMTP headers or forge the email's structure. Applied to every
// user-supplied field before it goes into the message body.
function clean(s) {
  // eslint-disable-next-line no-control-regex
  return s.replace(/[\x00-\x08\x0B-\x1F\x7F]/g, "");
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

  let body;
  try {
    body = await request.json();
  } catch {
    return bad(400, "invalid JSON");
  }

  const message = clean((body.message ?? "").toString().trim());
  const contact = clean((body.contact ?? "").toString().trim());
  const meta = clean((body.meta ?? "").toString().trim()); // "AVA 0.65.2 · android · zh"
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

  const ip = request.headers.get("cf-connecting-ip") ?? "unknown";
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
