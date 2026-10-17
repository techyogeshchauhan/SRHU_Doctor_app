import { Router } from 'express';
import { getAuditEventsCollection } from '../db.js';
import { postAuditEventsSchema } from '../schemas.js';

const router = Router();

// POST /audit-events (batch; resending an event with the same id is a no-op)
router.post('/', async (req, res, next) => {
  try {
    const { events } = postAuditEventsSchema.parse(req.body);
    const receivedAt = new Date();

    const result = await getAuditEventsCollection().bulkWrite(
      events.map((e) => ({
        updateOne: {
          filter: { _id: e._id },
          update: {
            $setOnInsert: {
              _id: e._id,
              sessionId: e.sessionId ?? null,
              type: e.type,
              screen: e.screen ?? null,
              data: e.data ?? {},
              occurredAt: new Date(e.occurredAt),
              receivedAt,
            },
          },
          upsert: true,
        },
      })),
      { ordered: false }
    );

    res.status(200).json({ success: true, count: events.length, inserted: result.upsertedCount });
  } catch (err) {
    next(err);
  }
});

export default router;
