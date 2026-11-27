-- pricing_blueprint.sql
-- The 2026-11-26 Linen pricing blueprint, server side.
--
-- What this does:
--   1. Adds bookings.frequency (one_time, weekly, every_2_weeks,
--      every_4_weeks) so the server can tell the recurring frequencies
--      apart. bookings.recurring stays as the coarse on/off signal.
--   2. Rewrites price_booking() to price from the blueprint directly:
--      hardcoded Standard / Deep / Move-In-Move-Out matrices and the
--      sheet add-on and bundle prices (the services and add_ons catalog
--      tables are stale and no longer consulted), the frequency discount
--      applied to the base price only, bundle coverage so a bundle and
--      its own components never charge twice, and pro pay at a flat
--      80 percent of the subtotal.
--
-- The old function definition is preserved for rollback in
-- backend-price-booking-before-2026-11-26.sql at the repo root of the
-- Linen workspace (re-running it restores the old pricing; the
-- frequency column can stay, the old function ignores it).
--
-- Applied live to project vftlwlnbfqqqxfdscato on 2026-11-26.

ALTER TABLE public.bookings ADD COLUMN frequency text;

ALTER TABLE public.bookings ADD CONSTRAINT bookings_frequency_check
  CHECK (frequency IS NULL OR frequency IN ('one_time', 'weekly', 'every_2_weeks', 'every_4_weeks'));

-- bookings.service_id has a foreign key into services, and the stale
-- catalog had no 'move' row, so every Move-In / Move-Out insert failed
-- the key before pricing even ran. This row exists to satisfy the key;
-- its price columns carry the blueprint From figures for reference but
-- price_booking() never reads them.
INSERT INTO public.services (id, name, client_price_cents, pro_pay_cents, base_minutes, blurb, tag, sort)
VALUES ('move', 'Move-In / Move-Out', 17900, 14320, 240, 'Detailed cleaning for empty or mostly empty properties.', NULL, 3);

CREATE OR REPLACE FUNCTION public.price_booking()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  norm_baths int;
  base int;
  pct int;
  discounted int;
  extras int := 0;
  bundle_total int := 0;
  cov_oven int := 0;
  cov_fridge int := 0;
  cov_linens int := 0;
  cov_baseboards int := 0;
  cov_blinds int := 0;
  cov_dishes int := 0;
  cov_laundry int := 0;
  ids text[] := COALESCE(NEW.add_on_ids, ARRAY[]::text[]);
  subtotal int;
BEGIN
  -- Base price from the hardcoded blueprint matrices. Mirrors the app
  -- Pricing enum, including its rule that a configuration the table does
  -- not list takes the highest listed price for that bedroom count.
  IF NEW.service_id NOT IN ('standard', 'deep', 'move') THEN
    RAISE EXCEPTION 'Unknown service';
  END IF;

  IF NEW.beds >= 6 THEN
    -- 6+ bedrooms price from the From figure for the service.
    base := CASE NEW.service_id
      WHEN 'deep' THEN 52900
      WHEN 'move' THEN 57900
      ELSE 34900
    END;
  ELSIF NEW.service_id = 'move' THEN
    -- Move-In / Move-Out prices by bedroom count only.
    base := (ARRAY[17900, 21900, 27900, 34900, 42900, 49900])[GREATEST(NEW.beds, 0) + 1];
  ELSE
    norm_baths := LEAST(GREATEST(COALESCE(NEW.baths, 1), 1), 4);
    SELECT m.price INTO base
    FROM (VALUES
      ('standard', 0, 1, 9900),
      ('standard', 1, 1, 11900), ('standard', 1, 2, 13900),
      ('standard', 2, 1, 14900), ('standard', 2, 2, 16900),
      ('standard', 3, 1, 18900), ('standard', 3, 2, 19900), ('standard', 3, 3, 22900),
      ('standard', 4, 2, 23900), ('standard', 4, 3, 26900), ('standard', 4, 4, 29900),
      ('standard', 5, 3, 29900), ('standard', 5, 4, 32900),
      ('deep', 0, 1, 14900),
      ('deep', 1, 1, 17900), ('deep', 1, 2, 19900),
      ('deep', 2, 1, 21900), ('deep', 2, 2, 24900),
      ('deep', 3, 1, 27900), ('deep', 3, 2, 29900), ('deep', 3, 3, 33900),
      ('deep', 4, 2, 35900), ('deep', 4, 3, 39900), ('deep', 4, 4, 44900),
      ('deep', 5, 3, 44900), ('deep', 5, 4, 48900)
    ) AS m(service_id, beds, baths, price)
    WHERE m.service_id = NEW.service_id AND m.beds = GREATEST(NEW.beds, 0)
    ORDER BY (m.baths = norm_baths) DESC, m.price DESC
    LIMIT 1;
  END IF;

  IF base IS NULL THEN RAISE EXCEPTION 'Unknown service'; END IF;

  -- Frequency discount on the base price only, never on extras.
  -- Fallback: a booking with no frequency that still says recurring is
  -- read as weekly, which is what the old code's flat 15 percent meant.
  pct := CASE NEW.frequency
    WHEN 'weekly' THEN 15
    WHEN 'every_2_weeks' THEN 10
    WHEN 'every_4_weeks' THEN 5
    ELSE 0
  END;
  IF NEW.frequency IS NULL AND COALESCE(NEW.recurring, false) THEN
    pct := 15;
  END IF;
  discounted := round(base * (100 - pct) / 100.0)::int;

  -- Bundles: each adds its bundle price and covers its components, so a
  -- covered single below charges only what the coverage leaves over.
  IF 'bundle_kitchen' = ANY(ids) THEN
    bundle_total := bundle_total + 4000;
    cov_oven := cov_oven + 1; cov_fridge := cov_fridge + 1;
  END IF;
  IF 'bundle_bedroom' = ANY(ids) THEN
    bundle_total := bundle_total + 1500;
    cov_linens := cov_linens + 2;
  END IF;
  IF 'bundle_detail' = ANY(ids) THEN
    bundle_total := bundle_total + 3500;
    cov_baseboards := cov_baseboards + 1; cov_blinds := cov_blinds + 2;
  END IF;
  IF 'bundle_convenience' = ANY(ids) THEN
    bundle_total := bundle_total + 3500;
    cov_laundry := cov_laundry + 1; cov_dishes := cov_dishes + 1; cov_linens := cov_linens + 1;
  END IF;

  -- Singles at quantity one (the app sends each chosen id once), priced
  -- only past bundle coverage. Laundry is the exception: it prices per
  -- load from laundry_loads, again past coverage.
  extras := bundle_total;
  IF 'oven' = ANY(ids) THEN extras := extras + 2500 * GREATEST(1 - cov_oven, 0); END IF;
  IF 'fridge' = ANY(ids) THEN extras := extras + 2500 * GREATEST(1 - cov_fridge, 0); END IF;
  IF 'linens' = ANY(ids) THEN extras := extras + 1000 * GREATEST(1 - cov_linens, 0); END IF;
  IF 'dishes' = ANY(ids) THEN extras := extras + 1500 * GREATEST(1 - cov_dishes, 0); END IF;
  IF 'baseboards' = ANY(ids) THEN extras := extras + 2500 * GREATEST(1 - cov_baseboards, 0); END IF;
  IF 'blinds' = ANY(ids) THEN extras := extras + 1000 * GREATEST(1 - cov_blinds, 0); END IF;
  IF 'windows' = ANY(ids) THEN extras := extras + 500; END IF;
  IF 'cabinets' = ANY(ids) THEN extras := extras + 2500; END IF;
  IF 'petHair' = ANY(ids) THEN extras := extras + 1500; END IF;
  IF 'balcony' = ANY(ids) THEN extras := extras + 2000; END IF;
  IF 'garage' = ANY(ids) THEN extras := extras + 2500; END IF;
  IF 'fan' = ANY(ids) THEN extras := extras + 1000; END IF;
  IF 'wallSpot' = ANY(ids) THEN extras := extras + 2000; END IF;
  IF 'bathDetail' = ANY(ids) THEN extras := extras + 1500; END IF;
  IF 'laundry' = ANY(ids) THEN
    extras := extras + 1500 * GREATEST(COALESCE(NEW.laundry_loads, 1) - cov_laundry, 0);
  END IF;

  subtotal := discounted + extras;
  NEW.client_total_cents := subtotal;
  -- Flat payout split: 80 percent cleaner, 20 percent Linen.
  NEW.pro_pay_cents := round(subtotal * 0.8)::int;
  -- The blueprint carries no per service durations and the app shows
  -- none, so durations are set here: Standard 120, Deep 240, Move 240.
  NEW.duration_minutes := CASE NEW.service_id
    WHEN 'standard' THEN 120
    WHEN 'deep' THEN 240
    ELSE 240
  END;
  NEW.status := 'searching';
  NEW.specialist_id := NULL;
  NEW.tip_cents := 0;
  NEW.rating := NULL;
  SELECT name INTO NEW.homeowner_name FROM profiles WHERE id = NEW.homeowner_id;
  RETURN NEW;
END $function$
