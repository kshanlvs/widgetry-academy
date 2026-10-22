// Talks to the Claude API. Kept apart from the route so tests can swap in a fake model (setChatModel).
import Anthropic from "@anthropic-ai/sdk";
import { config } from "./config.js";
import { HttpError } from "./errors.js";

export type ChatRole = "user" | "assistant";
export interface ChatTurn { role: ChatRole; content: string }
export interface ChatReply { text: string; stopReason: string | null; inputTokens: number; outputTokens: number }
export type ChatModel = (system: string, messages: ChatTurn[]) => Promise<ChatReply>;

// The rules every reply follows. The user never sees or changes this; it lives only on the server.
export const SYSTEM_PROMPT = `You are the Widgetry Academy tutor, helping students learn Flutter and Dart.
Students range from Class 10 to graduates, so explain simply first and add depth if they ask.
- Keep answers short: under 150 words plus at most one small code example, unless the student asks for more.
- Use Flutter and Dart code in fenced code blocks.
- Only help with Flutter, Dart, mobile app development and closely related tools (Git, Firebase, APIs). For anything else, say politely that you can only help with app development.
- Never state course fees, batch dates, timings, seat counts or refund rules: you don't have current information. Point students to widgetryacademy.in or the academy's WhatsApp for those.
- If you are not sure about something (a package version, an API that may have changed), say so instead of guessing.`;

let client: Anthropic | null = null;
let override: ChatModel | null = null;
/** Tests replace the real model with a fake one; pass null to restore. */
export function setChatModel(m: ChatModel | null) { override = m; }

const claude: ChatModel = async (system, messages) => {
  if (!config.anthropic.apiKey) throw new HttpError(503, "The tutor isn't set up yet. Please try again later.");
  client ??= new Anthropic({ apiKey: config.anthropic.apiKey });
  try {
    const res = await client.messages.create({
      model: config.anthropic.model,
      max_tokens: config.anthropic.maxTokens,
      system,
      messages,
    });
    // A reply can hold several blocks (e.g. "thinking" first), so keep only the text ones, never just content[0]
    const text = res.content.flatMap(b => (b.type === "text" ? [b.text] : [])).join("\n").trim();
    return { text, stopReason: res.stop_reason ?? null, inputTokens: res.usage.input_tokens, outputTokens: res.usage.output_tokens };
  } catch (e) {
    if (e instanceof Anthropic.APIError) {
      console.error(`[chat] Claude API ${e.status}: ${e.message}`);
      // 429 = our API rate limit, 529 = Claude overloaded, 5xx = their side: all worth retrying later
      if (e.status === 429 || e.status === 529 || (e.status ?? 0) >= 500)
        throw new HttpError(503, "The tutor is busy right now. Please try again in a minute.");
      throw new HttpError(502, "The tutor couldn't answer that. Please try again.");
    }
    throw e;
  }
};

export function askModel(system: string, messages: ChatTurn[]): Promise<ChatReply> {
  return (override ?? claude)(system, messages);
}
