// Powers the payout setup web page. The page arrives with a one time code
// from the app (connect-handoff) and trades it here for a page token plus
// the first Stripe Account Session client secret. Later secret refreshes
// send the page token instead. Page tokens are stored as SHA 256 hashes and
// last thirty minutes. Deploy with verify_jwt off: the code and the page
// token are the credentials, checked against connect_handoffs on every call.
import { createOnboardingSession, ensurePayoutAccount, json, serviceClient } from "../_shared/connect.ts";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function withCors(res: Response): Response {
  for (const [k, v] of Object.entries(CORS)) res.headers.set(k, v);
  return res;
}

function randomHex(bytes: number): string {
  const buf = new Uint8Array(bytes);
  crypto.getRandomValues(buf);
  return Array.from(buf, (b) => b.toString(16).padStart(2, "0")).join("");
}

async function sha256Hex(text: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  if (req.method !== "POST") return withCors(json({ error: "method_not_allowed" }, 405));
  const body = await req.json().catch(() => ({}));
  const sb = serviceClient();
  const nowIso = new Date().toISOString();

  try {
    if (typeof body.code === "string" && body.code) {
      const { data: row } = await sb
        .from("connect_handoffs")
        .select("*")
        .eq("code", body.code)
        .maybeSingle();
      if (!row || row.page_token_hash || row.expires_at < nowIso) {
        return withCors(json({ error: "invalid_code" }, 401));
      }
      const pageToken = randomHex(32);
      const upd = await sb
        .from("connect_handoffs")
        .update({
          page_token_hash: await sha256Hex(pageToken),
          expires_at: new Date(Date.now() + 2 * 60 * 60 * 1000).toISOString(),
        })
        .eq("code", body.code)
        .select()
        .single();
      if (upd.error) return withCors(json({ error: upd.error.message }, 500));
      const payout = await ensurePayoutAccount(sb, row.profile_id);
      const clientSecret = await createOnboardingSession(payout.stripe_account_id);
      return withCors(json({ client_secret: clientSecret, page_token: pageToken }));
    }

    if (typeof body.page_token === "string" && body.page_token) {
      const hash = await sha256Hex(body.page_token);
      const { data: row } = await sb
        .from("connect_handoffs")
        .select("*")
        .eq("page_token_hash", hash)
        .maybeSingle();
      if (!row || row.expires_at < nowIso) {
        return withCors(json({ error: "invalid_page_token" }, 401));
      }
      const payout = await ensurePayoutAccount(sb, row.profile_id);
      const clientSecret = await createOnboardingSession(payout.stripe_account_id);
      return withCors(json({ client_secret: clientSecret }));
    }

    return withCors(json({ error: "missing_code" }, 400));
  } catch (e) {
    return withCors(json({ error: "session_failed", message: e instanceof Error ? e.message : String(e) }, 502));
  }
});
