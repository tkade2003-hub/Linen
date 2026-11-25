// Starts or resumes Stripe Connect Express onboarding for the signed in
// cleaner and returns the hosted onboarding URL. Deploy with verify_jwt on.
import { callerId, json, serviceClient, stripe } from "../_shared/connect.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const profileId = callerId(req);
  if (!profileId) return json({ error: "unauthorized" }, 401);
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
    if (ins.error) return json({ error: ins.error.message }, 500);
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
      return json({ error: created.data?.error?.code ?? "stripe_error", message: created.data?.error?.message ?? "Stripe account creation failed" }, 502);
    }
    const upd = await sb
      .from("specialist_payouts")
      .update({ stripe_account_id: created.data.id, onboarding_status: "in_progress", updated_at: new Date().toISOString() })
      .eq("profile_id", profileId)
      .select()
      .single();
    if (upd.error) return json({ error: upd.error.message }, 500);
    row = upd.data;
  }

  const link = await stripe("/account_links", "POST", {
    account: row.stripe_account_id,
    refresh_url: "linen://payouts/refresh",
    return_url: "linen://payouts/return",
    type: "account_onboarding",
  });
  if (!link.ok) {
    return json({ error: link.data?.error?.code ?? "stripe_error", message: link.data?.error?.message ?? "Could not create the onboarding link" }, 502);
  }
  return json({ url: link.data.url, account_id: row.stripe_account_id });
});
