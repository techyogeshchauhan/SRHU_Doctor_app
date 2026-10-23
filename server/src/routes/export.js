import { Router } from 'express';
import { getAuditEventsCollection, getChatLogsCollection, getScreeningsCollection, getSessionsCollection } from '../db.js';
import { exportApiKeyAuth } from '../middleware/auth.js';
import {
  exportAuditEventsQuerySchema,
  exportChatLogsQuerySchema,
  exportQuerySchema,
  exportStatsQuerySchema,
  uuidSchema,
} from '../schemas.js';

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
  decision: 1,
  decisionRecordedAt: 1,
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

const DAY_MS = 24 * 60 * 60 * 1000;

/** { field: { $gte, $lte } } for the given range, or {} when open. */
function rangeMatch(field, from, to) {
  if (!from && !to) return {};
  const range = {};
  if (from) range.$gte = from;
  if (to) range.$lte = to;
  return { [field]: range };
}

/** [{ <as>: value, count }] for one field, most frequent first. */
function countBy(collection, match, field, as, limit = 50) {
  return collection
    .aggregate([
      { $match: match },
      { $group: { _id: `$${field}`, count: { $sum: 1 } } },
      { $sort: { count: -1, _id: 1 } },
      { $limit: limit },
      { $project: { _id: 0, [as]: { $ifNull: ['$_id', null] }, count: 1 } },
    ])
    .toArray();
}

// GET /export/stats?from=&to= (aggregates for the developer dashboard)
router.get('/stats', async (req, res, next) => {
  try {
    const filters = exportStatsQuerySchema.parse(req.query);
    const from = filters.from ? new Date(filters.from) : null;
    const to = filters.to ? new Date(filters.to) : null;

    const sessions = getSessionsCollection();
    const screenings = getScreeningsCollection();
    const chatLogs = getChatLogsCollection();
    const auditEvents = getAuditEventsCollection();

    const sessionMatch = rangeMatch('createdAt', from, to);
    const screeningMatch = rangeMatch('startedAt', from, to);
    const chatMatch = rangeMatch('createdAt', from, to);
    const auditMatch = rangeMatch('occurredAt', from, to);

    const dailyTo = to ?? new Date();
    const dailyFrom = from ?? new Date(dailyTo.getTime() - 29 * DAY_MS);

    const [
      sessionCount,
      screeningCount,
      completedCount,
      chatCount,
      chatNotFoundCount,
      auditCount,
      byDisease,
      triageCategories,
      sessionsByPlatform,
      sessionsByAppVersion,
      auditEventsByType,
      topStwRegions,
      dailyScreenings,
    ] = await Promise.all([
      sessions.countDocuments(sessionMatch),
      screenings.countDocuments(screeningMatch),
      screenings.countDocuments({ ...screeningMatch, status: 'completed' }),
      chatLogs.countDocuments(chatMatch),
      chatLogs.countDocuments({ ...chatMatch, found: false }),
      auditEvents.countDocuments(auditMatch),
      screenings
        .aggregate([
          { $match: screeningMatch },
          {
            $group: {
              _id: '$diseaseCode',
              total: { $sum: 1 },
              completed: { $sum: { $cond: [{ $eq: ['$status', 'completed'] }, 1, 0] } },
              avgDurationMs: { $avg: '$durationMs' },
            },
          },
          { $sort: { total: -1, _id: 1 } },
          { $project: { _id: 0, diseaseCode: '$_id', total: 1, completed: 1, avgDurationMs: 1 } },
        ])
        .toArray(),
      countBy(
        screenings,
        { ...screeningMatch, 'decision.category': { $exists: true } },
        'decision.category',
        'category'
      ),
      countBy(sessions, sessionMatch, 'platform', 'platform'),
      countBy(sessions, sessionMatch, 'appVersion', 'appVersion', 20),
      countBy(auditEvents, auditMatch, 'type', 'type'),
      countBy(
        auditEvents,
        { ...auditMatch, type: 'stw_pdf_opened', 'data.regionId': { $exists: true } },
        'data.regionId',
        'regionId',
        10
      ),
      screenings
        .aggregate([
          { $match: { startedAt: { $gte: dailyFrom, $lte: dailyTo } } },
          {
            $group: {
              _id: { $dateToString: { format: '%Y-%m-%d', date: '$startedAt', timezone: 'UTC' } },
              count: { $sum: 1 },
            },
          },
          { $sort: { _id: 1 } },
          { $project: { _id: 0, day: '$_id', count: 1 } },
        ])
        .toArray(),
    ]);

    res.status(200).json({
      generatedAt: new Date().toISOString(),
      range: { from: from?.toISOString() ?? null, to: to?.toISOString() ?? null },
      totals: {
        sessions: sessionCount,
        screenings: screeningCount,
        completedScreenings: completedCount,
        chatLogs: chatCount,
        chatLogsNotFound: chatNotFoundCount,
        auditEvents: auditCount,
      },
      screeningsByDisease: byDisease,
      triageCategories,
      sessionsByPlatform,
      sessionsByAppVersion,
      auditEventsByType,
      topStwRegions,
      daily: {
        from: dailyFrom.toISOString(),
        to: dailyTo.toISOString(),
        screenings: dailyScreenings,
      },
    });
  } catch (err) {
    next(err);
  }
});

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

// GET /export/audit-events?from=&to=&sessionId=&type=&limit=&cursor=&page=
router.get('/audit-events', async (req, res, next) => {
  try {
    const filters = exportAuditEventsQuerySchema.parse(req.query);
    const query = filters.type ? { type: filters.type } : {};
    const result = await paginate(getAuditEventsCollection(), filters, query, 'occurredAt');
    res.status(200).json(result);
  } catch (err) {
    next(err);
  }
});

export default router;
