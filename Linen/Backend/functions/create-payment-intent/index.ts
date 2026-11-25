// Creates (or returns) the Stripe PaymentIntent for a booking so the client
// can pay with the method they chose in the app, Apple Pay or a card. Both
// ride the same intent: automatic payment methods surface Apple Pay and
// cards in the payment sheet. Deploy with verify_jwt on.
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
    .select("id, homeowner_id, status, client_total_cents, payment_method, stripe_payment_intent_id")
    .eq("id", bookingId)
    .maybeSingle();
  if (!booking) return json({ error: "booking_not_found" }, 404);
  if (booking.homeowner_id !== profileId) return json({ error: "forbidden" }, 403);
  if (booking.status === "cancelled") return json({ error: "booking_cancelled" }, 409);
  if (!booking.client_total_cents || booking.client_total_cents <= 0) {
    return json({ error: "booking_not_priced" }, 409);
  }

  if (booking.stripe_payment_intent_id) {
    const existing = await stripe(`/payment_intents/${booking.stripe_payment_intent_id}`, "GET");
    if (existing.ok && existing.data.status !== "canceled") {
      return json({ client_secret: existing.data.client_secret, payment_intent_id: existing.data.id });
    }
  }

  const created = await stripe("/payment_intents", "POST", {
    amount: booking.client_total_cents,
    currency: "usd",
    automatic_payment_methods: { enabled: true },
    metadata: { booking_id: bookingId, homeowner_id: profileId, chosen_method: booking.payment_method ?? "apple_pay" },
  });
  if (!created.ok) {
    return json({ error: created.data?.error?.code ?? "stripe_error", message: created.data?.error?.message ?? "Could not create the payment" }, 502);
  }
  await sb
    .from("bookings")
    .update({ stripe_payment_intent_id: created.data.id })
    .eq("id", bookingId);
  return json({ client_secret: created.data.client_secret, payment_intent_id: created.data.id });
});
