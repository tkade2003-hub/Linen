-- Linen client payment choice, migration 009
-- Clients choose how to pay: Apple Pay or a card. The choice is stored on
-- the booking, and the payment state follows the Stripe PaymentIntent.

alter table bookings
  add column if not exists payment_method text not null default 'apple_pay'
    check (payment_method in ('apple_pay', 'card'));

alter table bookings
  add column if not exists payment_status text not null default 'unpaid'
    check (payment_status in ('unpaid', 'paid', 'failed', 'refunded'));

alter table bookings
  add column if not exists stripe_payment_intent_id text;
