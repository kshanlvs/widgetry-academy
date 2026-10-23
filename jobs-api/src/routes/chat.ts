// AI tutor chat. The server owns the history: the app sends only the new message and a conversation id,
// we load the past messages from the database, send everything to Claude, then save both sides.
// RAG: before asking Claude, we search Widgetry's own material for the question and add the best passages
// (plus live fees and dates) to the system prompt, so answers match what we teach and never use old prices.
import { Router } from "express";
import { z } from "zod";
import { query, tx } from "../db.js";
import { wrap, HttpError } from "../errors.js";
import { requireAuth } from "../auth.js";
import { config } from "../config.js";
import { askModel, buildSystem, type ChatTurn } from "../chat.js";
import { knowledge, formatReferences, sourcesOf } from "../rag.js";
import { academyFacts } from "../facts.js";

export const chatRouter = Router();

const sendBody = z.object({
  conversationId: z.coerce.number().int().positive().optional().nullable(),
  message: z.string().trim().min(1, "Type a question first").max(2000, "Please keep your question under 2000 characters"),
});
const idParam = z.coerce.number().int().positive();

/** The conversation, only if it belongs to this user (someone else's id looks the same as a missing one). */
async function ownConversation(id: number, uid: string) {
  const [conv] = await query<{ id: number }>("SELECT id FROM chat_conversations WHERE id = ? AND uid = ?", [id, uid]);
  if (!conv) throw new HttpError(404, "Conversation not found.");
  return conv;
}

chatRouter.post("/chat", requireAuth, wrap(async (req, res) => {
  const uid = req.user!.uid;
  const { conversationId, message } = sendBody.parse(req.body);

  // Cost guard: each user gets a fixed number of questions per rolling 24 hours
  const [{ n }] = await query<{ n: number }>(
    `SELECT COUNT(*) AS n FROM chat_messages m JOIN chat_conversations c ON c.id = m.conversation_id
     WHERE c.uid = ? AND m.role = 'user' AND m.created_at > NOW() - INTERVAL 1 DAY`, [uid]);
  if (Number(n) >= config.anthropic.dailyLimit)
    throw new HttpError(429, `You've asked ${config.anthropic.dailyLimit} questions in the last 24 hours. Please come back a little later.`);

  // The model has no memory: load the latest messages and resend them (newest N only, to cap tokens and cost)
  let history: ChatTurn[] = [];
  if (conversationId) {
    await ownConversation(conversationId, uid);
    const rows = await query<ChatTurn>(
      "SELECT role, content FROM chat_messages WHERE conversation_id = ? ORDER BY created_at DESC, id DESC LIMIT ?",
      [conversationId, config.anthropic.historyLimit]);
    history = rows.reverse();
    while (history[0]?.role === "assistant") history.shift();   // the API expects the first message to be the user's
  }

  // Retrieve: search with this question plus the previous one, so a follow-up like "show me an example" still
  // finds passages about the topic being discussed
  const lastQuestion = [...history].reverse().find(t => t.role === "user")?.content ?? "";
  const hits = knowledge().search(`${message}\n${lastQuestion}`);
  const sources = sourcesOf(hits);
  // Augment, then generate
  const system = buildSystem(await academyFacts(), formatReferences(hits));
  const reply = await askModel(system, [...history, { role: "user", content: message }]);
  if (!reply.text) throw new HttpError(502, "The tutor couldn't answer that. Please try again.");

  // Saved only after Claude answers, so a failed call leaves no half-finished turn behind
  const id = await tx(async c => {
    let convId = conversationId ?? 0;
    if (!convId) {
      const [r]: any = await c.execute("INSERT INTO chat_conversations (uid, title) VALUES (?, ?)", [uid, message.slice(0, 80)]);
      convId = r.insertId;
    } else {
      await c.execute("UPDATE chat_conversations SET updated_at = CURRENT_TIMESTAMP WHERE id = ?", [convId]);
    }
    await c.execute("INSERT INTO chat_messages (conversation_id, role, content) VALUES (?, 'user', ?)", [convId, message]);
    await c.execute("INSERT INTO chat_messages (conversation_id, role, content, input_tokens, output_tokens, sources) VALUES (?, 'assistant', ?, ?, ?, ?)",
      [convId, reply.text, reply.inputTokens, reply.outputTokens, sources.length ? JSON.stringify(sources) : null]);
    return Number(convId);
  });

  res.json({
    conversationId: id,
    reply: reply.text,
    // Widgetry pages the answer drew on (empty when it came from Claude's general knowledge)
    sources,
    // "max_tokens" means the answer was cut off by our length cap; the app can say "ask me to continue"
    truncated: reply.stopReason === "max_tokens",
    // What happened behind the scenes, for learning and cost tracking
    usage: {
      model: config.anthropic.model,
      contextMessages: history.length,      // earlier messages resent with this question (the model has no memory)
      retrieved: hits.map(h => ({ title: h.chunk.title, section: h.chunk.section, score: Math.round(h.score * 10) / 10 })), // what RAG found
      inputTokens: reply.inputTokens,       // everything sent: system prompt + history + question
      outputTokens: reply.outputTokens,     // the answer
      maxTokens: config.anthropic.maxTokens,
      stopReason: reply.stopReason,
      questionsLeftToday: Math.max(0, config.anthropic.dailyLimit - Number(n) - 1),
    },
  });
}));

// The user's conversations, newest first (for a "past chats" list)
chatRouter.get("/chat/conversations", requireAuth, wrap(async (req, res) => {
  const rows = await query("SELECT id, title, updated_at AS updatedAt FROM chat_conversations WHERE uid = ? ORDER BY updated_at DESC LIMIT 50", [req.user!.uid]);
  res.json({ conversations: rows });
}));

// All messages of one conversation, oldest first (to reopen a chat)
chatRouter.get("/chat/conversations/:id/messages", requireAuth, wrap(async (req, res) => {
  const id = idParam.parse(req.params.id);
  await ownConversation(id, req.user!.uid);
  const rows = await query<any>("SELECT role, content, input_tokens AS inputTokens, output_tokens AS outputTokens, sources, created_at AS createdAt FROM chat_messages WHERE conversation_id = ? ORDER BY created_at, id", [id]);
  // mysql2 returns JSON columns already parsed; a string means the driver didn't, so parse it here
  res.json({ messages: rows.map(r => ({ ...r, sources: typeof r.sources === "string" ? JSON.parse(r.sources) : r.sources ?? [] })) });
}));
