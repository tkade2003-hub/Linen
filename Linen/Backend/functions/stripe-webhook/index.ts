// Stripe webhook for the Linen platform account. Deploy with verify_jwt
// OFF and set STRIPE_WEBHOOK_SECRET. Keeps specialist_payouts in step with
// Stripe through account.updated, and confirms transfers.
import { json, serviceClient, statusForAccount } from "../_shared/connect.ts";

async function hmacHex(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message));
  return [...new Uint8Array(sig)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let out = 0;
  for (let i = 0; i < a.length; i++) out |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return out === 0;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const secret = Deno.env.get("STRIPE_WEBHOOK_SECRET");
  if (!secret) return json({ error: "webhook_not_configured" }, 500);
  const body = await req.text();
  const header = req.headers.get("Stripe-Signature") ?? "";
  const parts = Object.fromEntries(header.split(",").map((p) => {
    const i = p.indexOf("=");
    return [p.slice(0, i).trim(), p.slice(i + 1).trim()];
  }));
  const t = parts["t"];
  const v1 = parts["v1"];
  if (!t || !v1) return json({ error: "bad_signature" }, 400);
  if (Math.abs(Date.now() / 1000 - Number(t)) > 300) return json({ error: "stale_signature" }, 400);
  const expected = await hmacHex(secret, `${t}.${body}`);
  if (!timingSafeEqual(expected, v1)) return json({ error: "bad_signature" }, 400);

  const event = JSON.parse(body);
  const sb = serviceClient();

  if (event.type === "account.updated") {
    const acct = event.data.object;
    await sb
      .from("specialist_payouts")
      .update({
        charges_enabled: !!acct.charges_enabled,
        payouts_enabled: !!acct.payouts_enabled,
        details_submitted: !!acct.details_submitted,
        onboarding_status: statusForAccount(acct),
        updated_at: new Date().toISOString(),
      })
      .eq("stripe_account_id", acct.id);
  }

  if (event.type === "transfer.created") {
    const transfer = event.data.object;
    await sb
      .from("connect_transfers")
      .update({ status: "paid" })
      .eq("stripe_transfer_id", transfer.id)
      .eq("status", "pending");
  }

  return json({ received: true });
});
