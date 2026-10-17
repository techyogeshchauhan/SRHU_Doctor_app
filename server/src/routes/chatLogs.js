import { randomUUID } from 'crypto';
import { Router } from 'express';
import { getChatLogsCollection } from '../db.js';
import { postChatLogSchema } from '../schemas.js';

const router = Router();

// POST /chat-logs
router.post('/', async (req, res, next) => {
  try {
    const data = postChatLogSchema.parse(req.body);
    const chatLogs = getChatLogsCollection();

    const id = data._id || randomUUID();
    const now = data.createdAt ? new Date(data.createdAt) : new Date();

    const doc = {
      _id: id,
      sessionId: data.sessionId ?? null,
      userQuery: data.userQuery,
      extractedAnswer: data.extractedAnswer,
      regionId: data.regionId ?? null,
      chunkIds: data.chunkIds ?? [],
      source: data.source ?? null,
      found: data.found,
      retrieverType: data.retrieverType || 'bm25_pure_dart',
      createdAt: now,
    };

    await chatLogs.updateOne(
      { _id: id },
      { $setOnInsert: doc },
      { upsert: true }
    );

    res.status(200).json({ success: true, chatLogId: id });
  } catch (err) {
    next(err);
  }
});

export default router;
