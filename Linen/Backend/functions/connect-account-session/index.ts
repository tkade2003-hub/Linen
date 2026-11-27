// Creates a Stripe Account Session for the signed in cleaner's connected
// account so Stripe's embedded account onboarding component can run: inside
// the app through the StripeConnect SDK when the build links it, and on the
// Linen payout setup web page (Connect.js) when it does not. Creates the
// payout row and the Express connected account on first use, the same way
// connect-onboard does. The client secret is single use and short lived, so
// callers ask for a fresh one every time the component needs it and nothing
// here stores it. Deploy with verify_jwt on.
import { callerId, json, serviceClient, stripe } from "../_shared/connect.ts";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function withCors(res: Response): Response {
  for (const [k, v] of Object.entries(CORS)) res.headers.set(k, v);
  return res;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  if (req.method !== "POST") return withCors(json({ error: "method_not_allowed" }, 405));
  const profileId = callerId(req);
  if (!profileId) return withCors(json({ error: "unauthorized" }, 401));
  const sb = serviceClient();

  let { data: row } = await sb
    .from("specialist_payouts")
    .select("*")
    .eq("profile_id", profileId)
    .maybeSingle();
  if (!row) {
    const ins = await sb
      .from("specialist_payouts")
      .insert({ profile_id: profileId })
      .select()
      .single();
    if (ins.error) return withCors(json({ error: ins.error.message }, 500));
    row = ins.data;
  }

  if (!row.stripe_account_id) {
    const created = await stripe("/accounts", "POST", {
      type: "express",
      country: "US",
      business_type: "individual",
      capabilities: {
        card_payments: { requested: true },
        transfers: { requested: true },
      },
      metadata: { profile_id: profileId },
    });
    if (!created.ok) {
      return withCors(json({ error: created.data?.error?.code ?? "stripe_error", message: created.data?.error?.message ?? "Stripe account creation failed" }, 502));
    }
    const upd = await sb
      .from("specialist_payouts")
      .update({ stripe_account_id: created.data.id, onboarding_status: "in_progress", updated_at: new Date().toISOString() })
      .eq("profile_id", profileId)
      .select()
      .single();
    if (upd.error) return withCors(json({ error: upd.error.message }, 500));
    row = upd.data;
  }

  const session = await stripe("/account_sessions", "POST", {
    account: row.stripe_account_id,
    components: {
      account_onboarding: {
        enabled: true,
        features: { external_account_collection: true },
      },
    },
  });
  if (!session.ok) {
    return withCors(json({ error: session.data?.error?.code ?? "stripe_error", message: session.data?.error?.message ?? "Could not create the account session" }, 502));
  }
  return withCors(json({ client_secret: session.data.client_secret, account_id: row.stripe_account_id, payout: row }));
});
