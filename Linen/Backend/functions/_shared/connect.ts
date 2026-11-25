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
