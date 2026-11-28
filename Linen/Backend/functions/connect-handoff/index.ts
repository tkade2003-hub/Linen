// Mints a one time handoff code for the signed in cleaner. The app opens
// the payout setup web page with this code instead of putting the session
// token in the URL, because the token did not survive the jump from the app
// to the browser in testing. The code lives ten minutes and trades once for
// a page token in connect-session-exchange. Deploy with verify_jwt on.
import { callerId, json, serviceClient } from "../_shared/connect.ts";

function randomHex(bytes: number): string {
  const buf = new Uint8Array(bytes);
  crypto.getRandomValues(buf);
  return Array.from(buf, (b) => b.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const profileId = callerId(req);
  if (!profileId) return json({ error: "unauthorized" }, 401);
  const sb = serviceClient();
  const code = randomHex(24);
  const expires = new Date(Date.now() + 10 * 60 * 1000).toISOString();
  const { error } = await sb
    .from("connect_handoffs")
    .insert({ code, profile_id: profileId, expires_at: expires });
  if (error) return json({ error: error.message }, 500);
  return json({ code });
});
