/**
 * Branded Wor(l)ds — Guest Application Proxy
 *
 * Receives the application form payload, validates it,
 * checks the honeypot, then forwards to Power Automate.
 *
 * Required environment variables (set in Netlify UI or .env.local):
 *   FLOW_URL    — full HTTP trigger URL from Power Automate
 *   API_TOKEN   — secret token, checked by Power Automate against SharePoint
 *
 * Never put these values in frontend code or Git.
 */

const REQUIRED_FIELDS = [
  "guestName",
  "guestEmail",
  "guestCompany",
  "guestRole",
  "guestBio",
  "guestStory",
  "guestFit",
];

export default async function handler(req, context) {
  // Only POST allowed
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Environment variables must be set
  const flowUrl = process.env.FLOW_URL;
  const apiToken = process.env.API_TOKEN;

  if (!flowUrl || !apiToken) {
    console.error("Missing FLOW_URL or API_TOKEN environment variables.");
    return new Response(JSON.stringify({ error: "Server configuration error" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  let body;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Honeypot check — 'website' field must be empty
  if (body.website && body.website.trim() !== "") {
    // Silently accept to not reveal the trap
    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Required field validation
  const missing = REQUIRED_FIELDS.filter(
    (f) => !body[f] || String(body[f]).trim() === ""
  );
  if (missing.length > 0) {
    return new Response(
      JSON.stringify({ error: "Missing required fields", fields: missing }),
      { status: 400, headers: { "Content-Type": "application/json" } }
    );
  }

  // Basic email format check
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(body.guestEmail)) {
    return new Response(JSON.stringify({ error: "Invalid email address" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Build clean payload — only allow known fields, never proxy arbitrary data
  const payload = {
    guestId: body.guestId || crypto.randomUUID(),
    guestName: String(body.guestName).trim(),
    guestEmail: String(body.guestEmail).trim().toLowerCase(),
    guestCompany: String(body.guestCompany).trim(),
    guestRole: String(body.guestRole).trim(),
    guestBio: String(body.guestBio).trim(),
    guestStory: String(body.guestStory).trim(),
    guestFit: String(body.guestFit).trim(),
    website: "", // always empty after honeypot check
    submittedAt: new Date().toISOString(),
  };

  // Forward to Power Automate
  let paResponse;
  try {
    paResponse = await fetch(flowUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-token": apiToken,
      },
      body: JSON.stringify(payload),
    });
  } catch (err) {
    console.error("Power Automate request failed:", err);
    return new Response(JSON.stringify({ error: "Upstream request failed" }), {
      status: 502,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (!paResponse.ok) {
    console.error(`Power Automate returned ${paResponse.status}`);
    return new Response(
      JSON.stringify({ error: "Upstream error", status: paResponse.status }),
      { status: 502, headers: { "Content-Type": "application/json" } }
    );
  }

  return new Response(JSON.stringify({ ok: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
}
