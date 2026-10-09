import { Router } from 'express';
import { getScreeningsCollection } from '../db.js';
import {
  checkPhiKeywords,
  patchScreeningStatusSchema,
  postFindingsSchema,
  postMcqAttemptSchema,
  putResponseSchema,
  putScreeningSchema,
  replaceFindingsSchema,
  singleFindingSchema,
  uuidSchema,
} from '../schemas.js';

const router = Router();

// PUT /screenings/:id (create or ensure screening document)
router.put('/:id', async (req, res, next) => {
  try {
    const id = uuidSchema.parse(req.params.id);
    const data = putScreeningSchema.parse(req.body);
    const screenings = getScreeningsCollection();

    const now = new Date();
    const doc = {
      _id: id,
      sessionId: data.sessionId,
      diseaseCode: data.diseaseCode,
      progressState: data.progressState,
      isEligible: data.isEligible ?? null,
      status: data.status || data.progressState,
      startedAt: data.startedAt ? new Date(data.startedAt) : now,
      completedAt: data.completedAt ? new Date(data.completedAt) : null,
      updatedAt: now,
    };

    await screenings.updateOne(
      { _id: id },
      {
        $setOnInsert: {
          responses: [],
          findings: [],
          mcqAttempts: [],
          createdAt: now,
        },
        $set: doc,
      },
      { upsert: true }
    );

    res.status(200).json({ success: true, screeningId: id });
  } catch (err) {
    next(err);
  }
});

// PUT /screenings/:id/responses/:questionId (idempotent upsert inside responses array)
router.put('/:id/responses/:questionId', async (req, res, next) => {
  try {
    const id = uuidSchema.parse(req.params.id);
    const questionId = req.params.questionId;
    // The question id names the stored field, so it gets the same PHI check
    // as body keys (e.g. rejects a 'dob' answer).
    if (checkPhiKeywords({ [questionId]: true })) {
      return res.status(400).json({
        error: 'ValidationError',
        message: `Prohibited patient identifier question "${questionId}". No PHI may be submitted.`,
      });
    }
    const data = putResponseSchema.parse(req.body);
    const screenings = getScreeningsCollection();

    const answeredAt = data.answeredAt ? new Date(data.answeredAt) : new Date();

    const responseEntry = {
      questionId,
      value: data.value,
      unit: data.unit,
      inputMode: data.inputMode,
      answeredAt,
    };

    // Single atomic pipeline update replacing existing questionId entry or appending new
    const updateResult = await screenings.updateOne(
      { _id: id },
      [
        {
          $set: {
            responses: {
              $concatArrays: [
                {
                  $filter: {
                    input: { $ifNull: ['$responses', []] },
                    as: 'r',
                    cond: { $ne: ['$$r.questionId', questionId] },
                  },
                },
                [responseEntry],
              ],
            },
            updatedAt: new Date(),
          },
        },
      ]
    );

    if (updateResult.matchedCount === 0) {
      return res.status(404).json({ error: 'NotFound', message: 'Screening not found.' });
    }

    res.status(200).json({ success: true, screeningId: id, questionId });
  } catch (err) {
    next(err);
  }
});

// POST /screenings/:id/findings
router.post('/:id/findings', async (req, res, next) => {
  try {
    const id = uuidSchema.parse(req.params.id);
    const screenings = getScreeningsCollection();

    let findingsToAdd = [];
    if (Array.isArray(req.body.findings)) {
      const parsed = postFindingsSchema.parse(req.body);
      findingsToAdd = parsed.findings;
    } else {
      const single = singleFindingSchema.parse(req.body);
      findingsToAdd = [single];
    }

    const now = new Date();
    const formatted = findingsToAdd.map((f) => ({
      type: f.type,
      title: f.title,
      severity: f.severity,
      recommendations: f.recommendations,
      stwReference: f.stwReference,
      generatedAt: f.generatedAt ? new Date(f.generatedAt) : now,
    }));

    const result = await screenings.updateOne(
      { _id: id },
      {
        $push: { findings: { $each: formatted } },
        $set: { updatedAt: now },
      }
    );

    if (result.matchedCount === 0) {
      return res.status(404).json({ error: 'NotFound', message: 'Screening not found.' });
    }

    res.status(200).json({ success: true, count: formatted.length });
  } catch (err) {
    next(err);
  }
});

// PUT /screenings/:id/findings (replace with the latest snapshot; idempotent)
router.put('/:id/findings', async (req, res, next) => {
  try {
    const id = uuidSchema.parse(req.params.id);
    const { findings } = replaceFindingsSchema.parse(req.body);
    const screenings = getScreeningsCollection();

    const now = new Date();
    const formatted = findings.map((f) => ({
      type: f.type,
      title: f.title,
      severity: f.severity,
      recommendations: f.recommendations,
      stwReference: f.stwReference,
      generatedAt: f.generatedAt ? new Date(f.generatedAt) : now,
    }));

    const result = await screenings.updateOne(
      { _id: id },
      { $set: { findings: formatted, updatedAt: now } }
    );

    if (result.matchedCount === 0) {
      return res.status(404).json({ error: 'NotFound', message: 'Screening not found.' });
    }

    res.status(200).json({ success: true, count: formatted.length });
  } catch (err) {
    next(err);
  }
});

// POST /screenings/:id/mcq-attempts
router.post('/:id/mcq-attempts', async (req, res, next) => {
  try {
    const id = uuidSchema.parse(req.params.id);
    const data = postMcqAttemptSchema.parse(req.body);
    const screenings = getScreeningsCollection();

    const now = new Date();
    const attemptEntry = {
      questionId: data.questionId,
      selectedOption: data.selectedOption,
      isCorrect: data.isCorrect,
      answeredAt: data.answeredAt ? new Date(data.answeredAt) : now,
    };

    const result = await screenings.updateOne(
      { _id: id },
      {
        $push: { mcqAttempts: attemptEntry },
        $set: { updatedAt: now },
      }
    );

    if (result.matchedCount === 0) {
      return res.status(404).json({ error: 'NotFound', message: 'Screening not found.' });
    }

    res.status(200).json({ success: true, attempt: attemptEntry });
  } catch (err) {
    next(err);
  }
});

// PATCH /screenings/:id/status
router.patch('/:id/status', async (req, res, next) => {
  try {
    const id = uuidSchema.parse(req.params.id);
    const data = patchScreeningStatusSchema.parse(req.body);
    const screenings = getScreeningsCollection();

    const now = new Date();
    const updates = {
      status: data.status,
      progressState: data.status,
      updatedAt: now,
    };

    if (data.status === 'completed') {
      updates.completedAt = data.completedAt ? new Date(data.completedAt) : now;
    }

    const result = await screenings.updateOne({ _id: id }, { $set: updates });

    if (result.matchedCount === 0) {
      return res.status(404).json({ error: 'NotFound', message: 'Screening not found.' });
    }

    res.status(200).json({ success: true, screeningId: id, status: data.status });
  } catch (err) {
    next(err);
  }
});

// GET /screenings?sessionId=...
router.get('/', async (req, res, next) => {
  try {
    const sessionId = req.query.sessionId ? uuidSchema.parse(req.query.sessionId) : null;
    const screenings = getScreeningsCollection();

    const query = {};
    if (sessionId) {
      query.sessionId = sessionId;
    }

    const list = await screenings.find(query).sort({ startedAt: -1 }).toArray();
    res.status(200).json(list);
  } catch (err) {
    next(err);
  }
});

// GET /screenings/:id
router.get('/:id', async (req, res, next) => {
  try {
    const id = uuidSchema.parse(req.params.id);
    const screenings = getScreeningsCollection();

    const doc = await screenings.findOne({ _id: id });
    if (!doc) {
      return res.status(404).json({ error: 'NotFound', message: 'Screening not found.' });
    }

    res.status(200).json(doc);
  } catch (err) {
    next(err);
  }
});

export default router;
