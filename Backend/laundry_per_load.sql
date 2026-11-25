-- Laundry and fold becomes per load pricing: $17 per load, 1 to 10 loads.
-- bookings.laundry_loads carries the chosen count and price_booking multiplies.
-- Applied live to the Linen Supabase project (vftlwlnbfqqqxfdscato) on 2026-11-24.

alter table public.bookings
  add column if not exists laundry_loads int;

alter table public.bookings
  drop constraint if exists bookings_laundry_loads_range;

alter table public.bookings
  add constraint bookings_laundry_loads_range
  check (laundry_loads is null or (laundry_loads >= 1 and laundry_loads <= 10));

update public.add_ons set price_cents = 1700 where id = 'laundry';

create or replace function public.price_booking()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
DECLARE
  svc services%ROWTYPE;
  rooms int;
  extras int;
  total int;
BEGIN
  SELECT * INTO svc FROM services WHERE id = NEW.service_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Unknown service'; END IF;
  rooms := (NEW.beds - 2) * 2200 + (NEW.baths - 2) * 2800;
  SELECT COALESCE(SUM(CASE WHEN id = 'laundry' THEN price_cents * COALESCE(NEW.laundry_loads, 1) ELSE price_cents END), 0) INTO extras FROM add_ons WHERE id = ANY(NEW.add_on_ids);
  total := GREATEST(svc.client_price_cents + rooms + extras, 5000);
  IF NEW.recurring THEN total := round(total * 0.85); END IF;
  NEW.client_total_cents := total;
  NEW.pro_pay_cents := GREATEST(svc.pro_pay_cents + round((rooms + extras) * 0.8)::int, 4000);
  NEW.duration_minutes := svc.base_minutes;
  NEW.status := 'searching';
  NEW.specialist_id := NULL;
  NEW.tip_cents := 0;
  NEW.rating := NULL;
  SELECT name INTO NEW.homeowner_name FROM profiles WHERE id = NEW.homeowner_id;
  RETURN NEW;
END $function$;
