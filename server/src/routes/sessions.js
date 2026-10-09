import { Router } from 'express';
import { getSessionsCollection } from '../db.js';
import { createSessionSchema, updateSessionSchema, uuidSchema } from '../schemas.js';

const router = Router();

// POST /sessions (idempotent create or ensure)
router.post('/', async (req, res, next) => {
  try {
    const data = createSessionSchema.parse(req.body);
    const sessions = getSessionsCollection();

    const now = new Date();
    const doc = {
      _id: data._id,
      sessionToken: data.sessionToken,
      facilityName: data.facilityName ?? null,
      platform: data.platform,
      appVersion: data.appVersion,
      status: data.status,
      selectedConditions: data.selectedConditions ?? [],
      updatedAt: now,
    };

    await sessions.updateOne(
      { _id: data._id },
      {
        $setOnInsert: { createdAt: data.createdAt ? new Date(data.createdAt) : now },
        $set: doc,
      },
      { upsert: true }
    );

    res.status(200).json({ success: true, sessionId: data._id });
  } catch (err) {
    next(err);
  }
});

// PATCH /sessions/:id
router.patch('/:id', async (req, res, next) => {
  try {
    const id = uuidSchema.parse(req.params.id);
    const data = updateSessionSchema.parse(req.body);
    const sessions = getSessionsCollection();

    const updateFields = {
      ...data,
      ...(data.endedAt !== undefined && {
        endedAt: data.endedAt ? new Date(data.endedAt) : null,
      }),
      updatedAt: new Date(),
    };

    const result = await sessions.updateOne({ _id: id }, { $set: updateFields });

    if (result.matchedCount === 0) {
      return res.status(404).json({ error: 'NotFound', message: 'Session not found.' });
    }

    res.status(200).json({ success: true, sessionId: id });
  } catch (err) {
    next(err);
  }
});

// GET /sessions/:id
router.get('/:id', async (req, res, next) => {
  try {
    const id = uuidSchema.parse(req.params.id);
    const sessions = getSessionsCollection();

    const session = await sessions.findOne({ _id: id });
    if (!session) {
      return res.status(404).json({ error: 'NotFound', message: 'Session not found.' });
    }

    res.status(200).json(session);
  } catch (err) {
    next(err);
  }
});

export default router;
