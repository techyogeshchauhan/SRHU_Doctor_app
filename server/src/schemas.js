import { z } from 'zod';

const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export const uuidSchema = z.string().regex(uuidRegex, 'Invalid UUID format');

const PROHIBITED_PHI_KEYWORDS = [
  'name',
  'patientname',
  'patient_name',
  'mrn',
  'dob',
  'dateofbirth',
  'date_of_birth',
  'phone',
  'mobile',
  'address',
  'patient',
  'ssn',
  'aadhaar',
  'national_id',
];

export function checkPhiKeywords(obj, path = '') {
  if (!obj || typeof obj !== 'object') return null;

  for (const [key, value] of Object.entries(obj)) {
    const lowerKey = key.toLowerCase();
    // Allow legitimate system fields like 'facilityName' or 'diseaseCode'
    if (key !== 'facilityName') {
      for (const kw of PROHIBITED_PHI_KEYWORDS) {
        if (lowerKey === kw || lowerKey.startsWith(kw + '_') || lowerKey.endsWith('_' + kw)) {
          return `${path ? path + '.' : ''}${key}`;
        }
      }
    }

    if (value && typeof value === 'object') {
      const nested = checkPhiKeywords(value, `${path ? path + '.' : ''}${key}`);
      if (nested) return nested;
    }
  }

  return null;
}

const phiGuard = (val, ctx) => {
  const phiKey = checkPhiKeywords(val);
  if (phiKey) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: `Prohibited patient identifier field detected: "${phiKey}". No PHI (name, MRN, DOB, phone, address) may be submitted.`,
      path: [phiKey],
    });
  }
};

// Session schemas
export const createSessionSchema = z
  .object({
    _id: uuidSchema,
    sessionToken: z.string().min(1),
    facilityName: z.string().nullable().optional(),
    platform: z.string().min(1),
    appVersion: z.string().min(1),
    status: z.enum(['in_progress', 'completed', 'abandoned']).default('in_progress'),
    // Disease codes chosen for this assessment (empty for a chat-only session).
    selectedConditions: z.array(z.string().min(1).max(64)).max(20).optional(),
    createdAt: z.string().datetime().optional(),
    updatedAt: z.string().datetime().optional(),
  })
  .strict()
  .superRefine(phiGuard);

export const updateSessionSchema = z
  .object({
    status: z.enum(['in_progress', 'completed', 'abandoned']).optional(),
    facilityName: z.string().nullable().optional(),
    endedAt: z.string().datetime().nullable().optional(),
  })
  .strict()
  .superRefine(phiGuard);

// Screening schemas
export const putScreeningSchema = z
  .object({
    sessionId: uuidSchema,
    diseaseCode: z.string().min(1),
    progressState: z.enum(['in_progress', 'completed', 'abandoned']).default('in_progress'),
    isEligible: z.boolean().nullable().optional(),
    startedAt: z.string().datetime().optional(),
    completedAt: z.string().datetime().nullable().optional(),
    status: z.enum(['in_progress', 'completed', 'abandoned']).optional(),
  })
  .strict()
  .superRefine(phiGuard);

export const putResponseSchema = z
  .object({
    questionId: z.string().min(1).optional(),
    // null records that the clinician cleared the answer.
    value: z.union([z.string(), z.number(), z.boolean(), z.array(z.any()), z.record(z.any())]).nullable(),
    unit: z.string().nullable().optional(),
    inputMode: z.string().optional(),
    answeredAt: z.string().datetime().optional(),
  })
  .strict()
  .superRefine(phiGuard);

export const singleFindingSchema = z
  .object({
    type: z.string().min(1),
    title: z.string().min(1),
    severity: z.string().min(1),
    recommendations: z.union([z.array(z.string()), z.record(z.any())]),
    stwReference: z.string().optional(),
    generatedAt: z.string().datetime().optional(),
  })
  .strict()
  .superRefine(phiGuard);

export const postFindingsSchema = z
  .object({
    findings: z.array(singleFindingSchema).min(1),
  })
  .strict()
  .superRefine(phiGuard);

// Full snapshot of a screening's findings (may be empty).
export const replaceFindingsSchema = z
  .object({
    findings: z.array(singleFindingSchema),
  })
  .strict()
  .superRefine(phiGuard);

export const postMcqAttemptSchema = z
  .object({
    questionId: z.string().min(1),
    selectedOption: z.string().min(1),
    isCorrect: z.boolean(),
    answeredAt: z.string().datetime().optional(),
  })
  .strict()
  .superRefine(phiGuard);

export const patchScreeningStatusSchema = z
  .object({
    status: z.enum(['in_progress', 'completed', 'abandoned']),
    completedAt: z.string().datetime().nullable().optional(),
  })
  .strict()
  .superRefine(phiGuard);

// Chat log schemas
export const sourceMetaSchema = z
  .object({
    document: z.string().min(1),
    page: z.number().int().positive(),
    section: z.string().optional(),
  })
  .strict();

export const postChatLogSchema = z
  .object({
    _id: uuidSchema.optional(),
    sessionId: uuidSchema.nullable().optional(),
    userQuery: z.string().min(1),
    extractedAnswer: z.string().min(1),
    regionId: z.string().nullable().optional(),
    chunkIds: z.array(z.string()).optional(),
    // null for "not covered" / "did you mean" answers (no source box).
    source: sourceMetaSchema.nullable().optional(),
    found: z.boolean(),
    retrieverType: z.string().default('bm25_pure_dart'),
    createdAt: z.string().datetime().optional(),
  })
  .strict()
  .superRefine(phiGuard);

// Export query schema
export const exportQuerySchema = z
  .object({
    from: z.string().datetime().optional(),
    to: z.string().datetime().optional(),
    diseaseCode: z.string().optional(),
    page: z.string().regex(/^\d+$/).transform(Number).optional(),
    limit: z.string().regex(/^\d+$/).transform(Number).default('50'),
    cursor: z.string().optional(),
  })
  .strict();
