// Supabase Edge Function: suggest-whatsapp
// Reads a walk-in lead's comments + staleness and returns three professional
// WhatsApp follow-ups (nudge / firm / urgent) plus a short read and a recommended tone.
// The ANTHROPIC_API_KEY lives here as a Supabase secret — it is never exposed to the browser.
//
// Deploy (per Supabase project):
//   supabase functions deploy suggest-whatsapp
//   supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
// Or paste this file in Dashboard → Edge Functions and add the secret there.

const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY");

// Fast + cheap, well-suited to short message drafting. Switch to "claude-opus-4-8"
// for richer copy at higher cost, or "claude-sonnet-5" for a middle ground.
const MODEL = "claude-haiku-4-5";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(obj: unknown, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { ...CORS, "content-type": "application/json" },
  });
}

const SCHEMA = {
  type: "object",
  additionalProperties: false,
  properties: {
    analysis: {
      type: "string",
      description:
        "One or two sentences: how this lead is trending and why the recommended tone fits.",
    },
    recommendedTone: { type: "string", enum: ["nudge", "firm", "urgent"] },
    messages: {
      type: "object",
      additionalProperties: false,
      properties: {
        nudge: { type: "string" },
        firm: { type: "string" },
        urgent: { type: "string" },
      },
      required: ["nudge", "firm", "urgent"],
    },
  },
  required: ["analysis", "recommendedTone", "messages"],
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    if (!ANTHROPIC_API_KEY) {
      return json({ error: "Server not configured: ANTHROPIC_API_KEY missing" }, 500);
    }

    const body = await req.json().catch(() => ({}));
    const lead = (body && body.lead) || {};
    const name = String(lead.name || "there").slice(0, 80);
    const firstName = name.split(/\s+/)[0] || "there";
    const project = String(lead.project || "the project").slice(0, 80);
    const rep = String(lead.rep || "").slice(0, 60);
    const repFirst = rep ? rep.split(/\s+/)[0] : "";
    const stale = (lead && lead.stale) || {};
    const comments = Array.isArray(lead.comments) ? lead.comments.slice(-14) : [];

    const commentText =
      comments
        .map(
          (c: { date?: string; text?: string }) =>
            `- ${c && c.date ? c.date + ": " : ""}${String((c && c.text) || "").slice(0, 500)}`,
        )
        .join("\n") || "(no comments logged yet)";

    const trendLine =
      `${stale.level || "unknown"}` +
      (stale.days != null ? ` — ${stale.days} day(s) since the last update` : "") +
      (stale.overdue ? " — the scheduled follow-up is overdue" : "");

    const system = `You write WhatsApp follow-up messages for a real-estate developer's salesperson to send to a customer who physically visited the site (a "walk-in"). Your goal is not to inform — it is to PROVOKE A REPLY. Generic "just checking in" messages get ignored; every message must give the customer a concrete reason to text back and end with one clear, easy-to-answer question.

Write THREE versions of the same follow-up, escalating in pressure:

- "nudge": warm and low-pressure. A genuine, specific check-in that reopens the conversation and invites a reply. No scarcity, no guilt.
- "firm": more direct. Introduce a real reason to act now — a specific unit or price that may not last, a decision that's approaching — and push gently toward a next step (a call, a revisit, sharing a number). Confident, not pushy.
- "urgent": high pressure but still fully professional. Combine genuine urgency (a real deadline, limited availability, a decision window closing) with tasteful reciprocity — the salesperson gave real time when the customer visited and has been reaching out, so a brief reply is a reasonable ask. Convey "I've invested effort here and I'd appreciate the courtesy of a response" through respect and directness, never through guilt-tripping, sarcasm, or scolding. It should make the customer feel it would be unreasonable NOT to reply.

Hard rules:
- Sound like a polished, professional Indian real-estate consultant. Clear, correct English. NO Hindi words, NO "Bhabhi/Sir-ji/ji", NO slang, NO over-familiarity.
- At most one tasteful emoji per message, and only where it genuinely helps warmth. Often use none.
- Reference concrete specifics from the comments where natural (the exact unit/configuration they liked, their budget, the competitor they mentioned, loan status, family, timeline). Specificity is what earns a reply.
- Keep each message to about 2-4 short sentences. WhatsApp style: no markdown, no bullet points, no subject line.
- End EVERY message with a single, low-friction question the customer can answer in one line (e.g. "Shall I call you at 12 tomorrow?", "Would Saturday or Sunday suit you better?").
- Address the customer by first name: ${firstName}.
${repFirst ? `- Sign off with the salesperson's first name: ${repFirst}.` : "- Do not invent a sign-off name; leave it unsigned."}
- Also return a one- or two-sentence "analysis" of how the lead is trending, and set "recommendedTone" from it: fresh/engaged -> nudge; slowing down or comparing options -> firm; gone quiet / overdue / clearly stalling -> urgent.

Return only the structured object.`;

    const userMsg = `Customer first name: ${firstName}
Project visited: ${project}
Trend signal: ${trendLine}

Salesperson's own notes and comments on this customer (oldest first, newest last):
${commentText}`;

    const aiRes = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 1100,
        system,
        messages: [{ role: "user", content: userMsg }],
        output_config: { format: { type: "json_schema", schema: SCHEMA } },
      }),
    });

    if (!aiRes.ok) {
      const detail = (await aiRes.text().catch(() => "")).slice(0, 600);
      return json({ error: "AI request failed", status: aiRes.status, detail }, 502);
    }

    const data = await aiRes.json();
    const textBlock = (data.content || []).find(
      (b: { type?: string }) => b && b.type === "text",
    );
    let parsed: { messages?: Record<string, string> } | null = null;
    try {
      parsed = JSON.parse(String((textBlock && textBlock.text) || "").trim());
    } catch {
      parsed = null;
    }
    if (!parsed || !parsed.messages) {
      return json({ error: "Could not parse AI output" }, 502);
    }
    return json(parsed, 200);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
