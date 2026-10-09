import { Router } from 'express';
import { getScreeningsCollection } from '../db.js';
import { exportApiKeyAuth } from '../middleware/auth.js';
import { exportQuerySchema } from '../schemas.js';

const router = Router();

// Apply export-specific authentication (strictly rejects write keys)
router.use(exportApiKeyAuth);

// GET /export/screenings?from=&to=&diseaseCode=&limit=&cursor=&page=
router.get('/screenings', async (req, res, next) => {
  try {
    const filters = exportQuerySchema.parse(req.query);
    const screenings = getScreeningsCollection();

    const query = {};

    if (filters.diseaseCode) {
      query.diseaseCode = filters.diseaseCode;
    }

    if (filters.from || filters.to) {
      query.startedAt = {};
      if (filters.from) {
        query.startedAt.$gte = new Date(filters.from);
      }
      if (filters.to) {
        query.startedAt.$lte = new Date(filters.to);
      }
    }

    // Cursor-based pagination support
    if (filters.cursor) {
      query._id = { $lt: filters.cursor };
    }

    const limit = filters.limit;
    const page = filters.page || 1;
    const skip = filters.cursor ? 0 : (page - 1) * limit;

    const [total, data] = await Promise.all([
      screenings.countDocuments(query),
      screenings
        .find(query)
        .sort({ _id: -1, startedAt: -1 })
        .skip(skip)
        .limit(limit)
        .project({
          // Strictly de-identified projection (Zero PHI)
          _id: 1,
          sessionId: 1,
          diseaseCode: 1,
          progressState: 1,
          isEligible: 1,
          status: 1,
          startedAt: 1,
          completedAt: 1,
          responses: 1,
          findings: 1,
          mcqAttempts: 1,
        })
        .toArray(),
    ]);

    const nextCursor = data.length === limit ? data[data.length - 1]._id : null;

    res.status(200).json({
      page,
      limit,
      total,
      nextCursor,
      data,
    });
  } catch (err) {
    next(err);
  }
});

export default router;
