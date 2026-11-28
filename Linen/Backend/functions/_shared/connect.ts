// Shared helpers for the Linen Stripe Connect functions.
// The app sends the Rork Auth JWT. The Supabase gateway verifies it before
// the function runs (verify_jwt on), so reading the sub claim here is safe.
// Writes go through the service role because specialist_payouts and
// connect_transfers have no client write policies by design.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

export function callerId(req: Request): string | null {
  const auth = req.headers.get("Authorization") ?? "";
  const token = auth.replace(/^Bearer\s+/i, "");
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  try {
    const payload = JSON.parse(
      atob(parts[1].replace(/-/g, "+").replace(/_/g, "/")),
    );
    return typeof payload.sub === "string" && payload.sub ? payload.sub : null;
  } catch {
    return null;
  }
}

export function serviceClient() {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
}

function encodeForm(prefix: string, value: unknown, out: URLSearchParams) {
  if (value === null || value === undefined) return;
  if (typeof value === "object" && !Array.isArray(value)) {
    for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
      encodeForm(`${prefix}[${k}]`, v, out);
    }
    return;
  }
  if (Array.isArray(value)) {
    value.forEach((v, i) => encodeForm(`${prefix}[${i}]`, v, out));
    return;
  }
  out.append(prefix, String(value));
}

export async function stripe(
  path: string,
  method: "GET" | "POST",
  params?: Record<string, unknown>,
): Promise<{ ok: boolean; status: number; data: any }> {
  const key = Deno.env.get("STRIPE_SECRET_KEY");
  if (!key) return { ok: false, status: 500, data: { error: { code: "stripe_not_configured", message: "STRIPE_SECRET_KEY is not set" } } };
  const form = new URLSearchParams();
  if (params) for (const [k, v] of Object.entries(params)) encodeForm(k, v, form);
  const res = await fetch(`https://api.stripe.com/v1${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${key}`,
      ...(method === "POST" ? { "Content-Type": "application/x-www-form-urlencoded" } : {}),
    },
    body: method === "POST" ? form.toString() : undefined,
  });
  const data = await res.json().catch(() => ({}));
  return { ok: res.ok, status: res.status, data };
}

export function statusForAccount(acct: any): string {
  if (acct?.requirements?.disabled_reason) return "restricted";
  if (acct?.details_submitted && acct?.payouts_enabled) return "complete";
  return "in_progress";
}

/// Returns the cleaner's payout row, creating the row and the Stripe
/// Express connected account on first use. This is the Connect signup: the
/// account exists from here, and Stripe's onboarding component collects the
/// identity, tax, and bank details against it.
export async function ensurePayoutAccount(sb: any, profileId: string) {
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
    if (ins.error) throw new Error(ins.error.message);
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
      throw new Error(created.data?.error?.message ?? "Stripe account creation failed");
    }
    const upd = await sb
      .from("specialist_payouts")
      .update({ stripe_account_id: created.data.id, onboarding_status: "in_progress", updated_at: new Date().toISOString() })
      .eq("profile_id", profileId)
      .select()
      .single();
    if (upd.error) throw new Error(upd.error.message);
    row = upd.data;
  }
  return row;
}

/// Creates a single use Account Session for the embedded account
/// onboarding component on a connected account.
export async function createOnboardingSession(accountId: string) {
  const session = await stripe("/account_sessions", "POST", {
    account: accountId,
    components: {
      account_onboarding: {
        enabled: true,
        features: { external_account_collection: true },
      },
    },
  });
  if (!session.ok) {
    throw new Error(session.data?.error?.message ?? "Could not create the account session");
  }
  return session.data.client_secret as string;
}

export async function syncAccountRow(sb: any, profileId: string, acct: any) {
  const patch = {
    stripe_account_id: acct.id,
    charges_enabled: !!acct.charges_enabled,
    payouts_enabled: !!acct.payouts_enabled,
    details_submitted: !!acct.details_submitted,
    onboarding_status: statusForAccount(acct),
    updated_at: new Date().toISOString(),
  };
  const { data, error } = await sb
    .from("specialist_payouts")
    .update(patch)
    .eq("profile_id", profileId)
    .select()
    .single();
  if (error) throw new Error(error.message);
  return data;
}
