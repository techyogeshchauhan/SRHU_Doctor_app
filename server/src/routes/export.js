import { Router } from 'express';
import { getChatLogsCollection, getScreeningsCollection, getSessionsCollection } from '../db.js';
import { exportApiKeyAuth } from '../middleware/auth.js';
import { exportChatLogsQuerySchema, exportQuerySchema, uuidSchema } from '../schemas.js';

const router = Router();

// Apply export-specific authentication (strictly rejects write keys)
router.use(exportApiKeyAuth);

// Strictly de-identified projection (Zero PHI)
const screeningProjection = {
  _id: 1,
  sessionId: 1,
  diseaseCode: 1,
  progressState: 1,
  isEligible: 1,
  status: 1,
  startedAt: 1,
  completedAt: 1,
  durationMs: 1,
  responses: 1,
  findings: 1,
  mcqAttempts: 1,
};

// The per-device session token links every session from one device, so it
// is never exported.
const sessionProjection = { sessionToken: 0 };

/**
 * Cursor/page pagination shared by the list exports. [dateField] is the
 * field filtered by from/to.
 */
async function paginate(collection, filters, query, dateField, projection) {
  if (filters.sessionId) {
    query.sessionId = filters.sessionId;
  }

  if (filters.from || filters.to) {
    query[dateField] = {};
    if (filters.from) {
      query[dateField].$gte = new Date(filters.from);
    }
    if (filters.to) {
      query[dateField].$lte = new Date(filters.to);
    }
  }

  // Cursor-based pagination support
  if (filters.cursor) {
    query._id = { $lt: filters.cursor };
  }

  const limit = filters.limit;
  const page = filters.page || 1;
  const skip = filters.cursor ? 0 : (page - 1) * limit;

  let cursor = collection
    .find(query)
    .sort({ _id: -1, [dateField]: -1 })
    .skip(skip)
    .limit(limit);
  if (projection) cursor = cursor.project(projection);

  const [total, data] = await Promise.all([collection.countDocuments(query), cursor.toArray()]);

  const nextCursor = data.length === limit ? data[data.length - 1]._id : null;

  return { page, limit, total, nextCursor, data };
}

// GET /export/screenings?from=&to=&diseaseCode=&sessionId=&limit=&cursor=&page=
router.get('/screenings', async (req, res, next) => {
  try {
    const filters = exportQuerySchema.parse(req.query);
    const query = {};
    if (filters.diseaseCode) {
      query.diseaseCode = filters.diseaseCode;
    }
    const result = await paginate(
      getScreeningsCollection(),
      filters,
      query,
      'startedAt',
      screeningProjection
    );
    res.status(200).json(result);
  } catch (err) {
    next(err);
  }
});

// GET /export/screenings/:id
router.get('/screenings/:id', async (req, res, next) => {
  try {
    const id = uuidSchema.parse(req.params.id);
    const doc = await getScreeningsCollection().findOne(
      { _id: id },
      { projection: screeningProjection }
    );
    if (!doc) {
      return res.status(404).json({ error: 'NotFound', message: 'Screening not found.' });
    }
    res.status(200).json(doc);
  } catch (err) {
    next(err);
  }
});

// GET /export/sessions/:id
router.get('/sessions/:id', async (req, res, next) => {
  try {
    const id = uuidSchema.parse(req.params.id);
    const doc = await getSessionsCollection().findOne(
      { _id: id },
      { projection: sessionProjection }
    );
    if (!doc) {
      return res.status(404).json({ error: 'NotFound', message: 'Session not found.' });
    }
    res.status(200).json(doc);
  } catch (err) {
    next(err);
  }
});

// GET /export/chat-logs?from=&to=&sessionId=&limit=&cursor=&page=
router.get('/chat-logs', async (req, res, next) => {
  try {
    const filters = exportChatLogsQuerySchema.parse(req.query);
    const result = await paginate(getChatLogsCollection(), filters, {}, 'createdAt');
    res.status(200).json(result);
  } catch (err) {
    next(err);
  }
});

export default router;
