// Pays one completed booking out to the cleaner's connected account: pro
// base pay plus the full tip. Idempotent per booking. The transfer draws on
// the platform Stripe balance, which fills when client payments run through
// Stripe. Deploy with verify_jwt on.
import { callerId, json, serviceClient, stripe } from "../_shared/connect.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const profileId = callerId(req);
  if (!profileId) return json({ error: "unauthorized" }, 401);
  const body = await req.json().catch(() => ({}));
  const bookingId = body?.booking_id;
  if (!bookingId) return json({ error: "booking_id_required" }, 400);
  const sb = serviceClient();

  const { data: booking } = await sb
    .from("bookings")
    .select("id, specialist_id, status, pro_pay_cents, tip_cents")
    .eq("id", bookingId)
    .maybeSingle();
  if (!booking) return json({ error: "booking_not_found" }, 404);
  if (booking.specialist_id !== profileId) return json({ error: "forbidden" }, 403);
  if (booking.status !== "completed") return json({ error: "booking_not_completed" }, 409);

  const { data: existing } = await sb
    .from("connect_transfers")
    .select("*")
    .eq("booking_id", bookingId)
    .in("status", ["pending", "paid"])
    .maybeSingle();
  if (existing) return json({ transfer: existing, already: true });

  const { data: payout } = await sb
    .from("specialist_payouts")
    .select("*")
    .eq("profile_id", profileId)
    .maybeSingle();
  if (!payout?.stripe_account_id) return json({ error: "payout_account_missing" }, 409);
  if (!payout.payouts_enabled) return json({ error: "payouts_not_enabled" }, 409);

  const amount = (booking.pro_pay_cents ?? 0) + (booking.tip_cents ?? 0);
  if (amount <= 0) return json({ error: "nothing_to_pay" }, 400);

  const sent = await stripe("/transfers", "POST", {
    amount,
    currency: "usd",
    destination: payout.stripe_account_id,
    transfer_group: bookingId,
    metadata: { booking_id: bookingId, profile_id: profileId },
  });
  if (!sent.ok) {
    const code = sent.data?.error?.code ?? "stripe_error";
    await sb.from("connect_transfers").insert({
      booking_id: bookingId,
      profile_id: profileId,
      amount_cents: booking.pro_pay_cents ?? 0,
      tip_cents: booking.tip_cents ?? 0,
      status: "failed",
      failure_code: code,
    });
    return json({ error: code, message: sent.data?.error?.message ?? "Transfer failed" }, 502);
  }
  const ins = await sb
    .from("connect_transfers")
    .insert({
      booking_id: bookingId,
      profile_id: profileId,
      stripe_transfer_id: sent.data.id,
      amount_cents: booking.pro_pay_cents ?? 0,
      tip_cents: booking.tip_cents ?? 0,
      status: "paid",
    })
    .select()
    .single();
  if (ins.error) return json({ error: ins.error.message }, 500);
  return json({ transfer: ins.data });
});
