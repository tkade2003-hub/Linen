// Refreshes the signed in cleaner's payout flags from Stripe and returns
// the saved row. Deploy with verify_jwt on.
import { callerId, json, serviceClient, stripe, syncAccountRow } from "../_shared/connect.ts";

Deno.serve(async (req) => {
  const profileId = callerId(req);
  if (!profileId) return json({ error: "unauthorized" }, 401);
  const sb = serviceClient();
  const { data: row } = await sb
    .from("specialist_payouts")
    .select("*")
    .eq("profile_id", profileId)
    .maybeSingle();
  if (!row || !row.stripe_account_id) {
    return json({ payout: row ?? null });
  }
  const acct = await stripe(`/accounts/${row.stripe_account_id}`, "GET");
  if (!acct.ok) {
    return json({ error: acct.data?.error?.code ?? "stripe_error", message: acct.data?.error?.message ?? "Could not read the Stripe account" }, 502);
  }
  const updated = await syncAccountRow(sb, profileId, acct.data);
  return json({ payout: updated });
});
