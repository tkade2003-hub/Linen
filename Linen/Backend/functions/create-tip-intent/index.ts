// Creates (or returns) the Stripe PaymentIntent that actually collects a
// tip a homeowner left when rating a completed visit. The tip amount is
// read from the booking row the rate_booking function priced, never from
// the client. Until this intent succeeds, the tip is only recorded, and
// connect-payout will not pay it out. Deploy with verify_jwt on.
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
    .select("id, homeowner_id, status, tip_cents, tip_payment_intent_id, tip_paid_at")
    .eq("id", bookingId)
    .maybeSingle();
  if (!booking) return json({ error: "booking_not_found" }, 404);
  if (booking.homeowner_id !== profileId) return json({ error: "forbidden" }, 403);
  if (booking.tip_paid_at) return json({ error: "tip_already_paid" }, 409);
  if (!booking.tip_cents || booking.tip_cents <= 0) {
    return json({ error: "no_tip_recorded" }, 409);
  }

  if (booking.tip_payment_intent_id) {
    const existing = await stripe(`/payment_intents/${booking.tip_payment_intent_id}`, "GET");
    if (existing.ok && existing.data.status !== "canceled" && existing.data.amount === booking.tip_cents) {
      return json({ client_secret: existing.data.client_secret });
    }
  }

  const created = await stripe("/payment_intents", "POST", {
    amount: booking.tip_cents,
    currency: "usd",
    automatic_payment_methods: { enabled: true },
    metadata: { booking_id: bookingId, homeowner_id: profileId, kind: "tip" },
  });
  if (!created.ok) {
    return json({ error: created.data?.error?.code ?? "stripe_error", message: created.data?.error?.message ?? "Could not create the tip payment" }, 502);
  }
  await sb
    .from("bookings")
    .update({ tip_payment_intent_id: created.data.id })
    .eq("id", bookingId);
  return json({ client_secret: created.data.client_secret });
});
