import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';
import { MongoMemoryServer } from 'mongodb-memory-server';
import request from 'supertest';

import { createApp } from '../src/app.js';
import { buildMongoUri, config } from '../src/config.js';
import { closeDatabase, connectToDatabase, getChatLogsCollection, getScreeningsCollection } from '../src/db.js';

describe('Neonatal STW REST API Backend', () => {
  let mongod;
  let app;
  const testApiKey = 'stw_dev_client_key_12345';
  const testExportKey = 'stw_research_export_key_67890';
  const testSessionId = '11111111-1111-4111-8111-111111111111';
  const testScreeningId = '22222222-2222-4222-8222-222222222222';

  before(async () => {
    // Start in-memory MongoDB instance
    mongod = await MongoMemoryServer.create();
    const uri = mongod.getUri();

    // Connect to in-memory DB
    await connectToDatabase(uri, 'neonatal_stw_test');
    // Test keys, independent of the real keys in server/.env.
    config.apiKeys = [testApiKey];
    config.exportApiKey = testExportKey;
    app = createApp();
  });

  after(async () => {
    await closeDatabase();
    if (mongod) {
      await mongod.stop();
    }
  });

  it('GET /health returns 200 and connected status', async () => {
    const res = await request(app).get('/health');
    assert.equal(res.status, 200);
    assert.equal(res.body.status, 'ok');
    assert.equal(res.body.db, 'connected');
  });

  it('Auth: missing key returns 401', async () => {
    const res = await request(app)
      .post('/sessions')
      .send({
        _id: testSessionId,
        sessionToken: 'token-123',
        platform: 'android',
        appVersion: '0.1.0',
      });

    assert.equal(res.status, 401);
    assert.equal(res.body.error, 'Unauthorized');
  });

  it('Auth: wrong key returns 401', async () => {
    const res = await request(app)
      .post('/sessions')
      .set('x-api-key', 'wrong_key_xyz')
      .send({
        _id: testSessionId,
        sessionToken: 'token-123',
        platform: 'android',
        appVersion: '0.1.0',
      });

    assert.equal(res.status, 401);
    assert.equal(res.body.error, 'Unauthorized');
  });

  it('Validation: rejects unknown/PHI-like fields (strict validation)', async () => {
    const res = await request(app)
      .post('/sessions')
      .set('x-api-key', testApiKey)
      .send({
        _id: testSessionId,
        sessionToken: 'token-123',
        platform: 'android',
        appVersion: '0.1.0',
        patientName: 'Baby Boy Doe', // PHI field should be rejected!
        patientDob: '2024-01-01',
      });

    assert.equal(res.status, 400);
    assert.equal(res.body.error, 'ValidationError');
    assert.ok(
      res.body.details.some((d) => d.message.toLowerCase().includes('phi') || d.message.toLowerCase().includes('unrecognized'))
    );
  });

  it('Startup: missing required env variable stops startup with clear message', () => {
    assert.throws(
      () => {
        buildMongoUri({
          MONGODB_USERNAME: 'user',
          // Missing MONGODB_PASSWORD and MONGODB_HOST
        });
      },
      (err) => {
        assert.ok(err.message.includes('Missing required MongoDB environment variable(s)'));
        assert.ok(err.message.includes('MONGODB_PASSWORD'));
        assert.ok(err.message.includes('MONGODB_HOST'));
        // Verify secrets are NOT printed in error
        assert.ok(!err.message.includes('not-a-real-password'));
        return true;
      }
    );
  });

  it('POST /sessions creates session successfully', async () => {
    const res = await request(app)
      .post('/sessions')
      .set('x-api-key', testApiKey)
      .send({
        _id: testSessionId,
        sessionToken: 'token-123',
        platform: 'android',
        appVersion: '0.1.0',
        facilityName: 'SMI Hospital',
      });

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.equal(res.body.sessionId, testSessionId);
  });

  it('Session: stores selected conditions, then is closed with an end time', async () => {
    const sessionId = '55555555-5555-4555-8555-555555555555';
    const created = await request(app)
      .post('/sessions')
      .set('x-api-key', testApiKey)
      .send({
        _id: sessionId,
        sessionToken: 'token-456',
        platform: 'android',
        appVersion: '0.1.0+18',
        selectedConditions: ['ancs', 'hypoglycemia'],
      });
    assert.equal(created.status, 200);

    const endedAt = '2026-10-09T10:00:00.000Z';
    const closed = await request(app)
      .patch(`/sessions/${sessionId}`)
      .set('x-api-key', testApiKey)
      .send({ status: 'completed', endedAt });
    assert.equal(closed.status, 200);

    const stored = await request(app)
      .get(`/export/sessions/${sessionId}`)
      .set('x-api-key', testExportKey);
    assert.deepEqual(stored.body.selectedConditions, ['ancs', 'hypoglycemia']);
    assert.equal(stored.body.status, 'completed');
    assert.equal(stored.body.endedAt, endedAt);
  });

  it('Session: PATCH rejects fields other than status / endedAt / facilityName', async () => {
    const res = await request(app)
      .patch(`/sessions/${testSessionId}`)
      .set('x-api-key', testApiKey)
      .send({ id: testSessionId, status: 'completed' });
    assert.equal(res.status, 400);
  });

  it('PUT /screenings/:id creates screening document', async () => {
    const res = await request(app)
      .put(`/screenings/${testScreeningId}`)
      .set('x-api-key', testApiKey)
      .send({
        sessionId: testSessionId,
        diseaseCode: 'respiratory_distress',
        progressState: 'in_progress',
        status: 'in_progress',
      });

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.equal(res.body.screeningId, testScreeningId);
  });

  it('Idempotence: putting the same response twice results in one entry', async () => {
    const questionId = 'gestational_age';

    // First response submission
    const res1 = await request(app)
      .put(`/screenings/${testScreeningId}/responses/${questionId}`)
      .set('x-api-key', testApiKey)
      .send({
        value: 32,
        unit: 'weeks',
        inputMode: 'slider',
      });
    assert.equal(res1.status, 200);

    // Second response submission with same questionId (updated value)
    const res2 = await request(app)
      .put(`/screenings/${testScreeningId}/responses/${questionId}`)
      .set('x-api-key', testApiKey)
      .send({
        value: 33,
        unit: 'weeks',
        inputMode: 'slider',
      });
    assert.equal(res2.status, 200);

    // Verify in database: exactly ONE response with questionId 'gestational_age'
    const col = getScreeningsCollection();
    const doc = await col.findOne({ _id: testScreeningId });
    assert.ok(doc);
    const matchingResponses = doc.responses.filter((r) => r.questionId === questionId);
    assert.equal(matchingResponses.length, 1, 'Should have exactly 1 response entry');
    assert.equal(matchingResponses[0].value, 33, 'Should reflect the latest updated value');
  });

  it('POST /screenings/:id/findings appends findings', async () => {
    const res = await request(app)
      .post(`/screenings/${testScreeningId}/findings`)
      .set('x-api-key', testApiKey)
      .send({
        findings: [
          {
            type: 'primary',
            title: 'Respiratory Distress with Silverman score >= 4',
            severity: 'moderate',
            recommendations: ['Initiate CPAP 5 cm H2O', 'Start caffeine citrate'],
            stwReference: 'STW Page 1 Algorithm',
          },
        ],
      });

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.equal(res.body.count, 1);
  });

  it('PUT /screenings/:id/responses/:questionId accepts null for a cleared answer', async () => {
    const res = await request(app)
      .put(`/screenings/${testScreeningId}/responses/rd_signs`)
      .set('x-api-key', testApiKey)
      .send({ value: null });
    assert.equal(res.status, 200);

    const doc = await getScreeningsCollection().findOne({ _id: testScreeningId });
    const entry = doc.responses.find((r) => r.questionId === 'rd_signs');
    assert.equal(entry.value, null);
  });

  it('PUT /screenings/:id/responses/dob is rejected as PHI', async () => {
    const res = await request(app)
      .put(`/screenings/${testScreeningId}/responses/dob`)
      .set('x-api-key', testApiKey)
      .send({ value: '2026-09-01' });
    assert.equal(res.status, 400);

    const doc = await getScreeningsCollection().findOne({ _id: testScreeningId });
    assert.ok(!doc.responses.some((r) => r.questionId === 'dob'));
  });

  it('PUT /screenings/:id/findings replaces findings instead of appending', async () => {
    const finding = (title) => ({
      type: 'treatment',
      title,
      severity: 'action',
      recommendations: { actions: ['Start CPAP'], why: [] },
    });

    for (const titles of [['A', 'B'], ['C']]) {
      const res = await request(app)
        .put(`/screenings/${testScreeningId}/findings`)
        .set('x-api-key', testApiKey)
        .send({ findings: titles.map(finding) });
      assert.equal(res.status, 200);
    }

    const doc = await getScreeningsCollection().findOne({ _id: testScreeningId });
    assert.deepEqual(doc.findings.map((f) => f.title), ['C']);

    const empty = await request(app)
      .put(`/screenings/${testScreeningId}/findings`)
      .set('x-api-key', testApiKey)
      .send({ findings: [] });
    assert.equal(empty.status, 200);

    const missing = await request(app)
      .put('/screenings/33333333-3333-4333-8333-333333333333/findings')
      .set('x-api-key', testApiKey)
      .send({ findings: [] });
    assert.equal(missing.status, 404);
  });

  it('POST /screenings/:id/mcq-attempts records MCQ attempt', async () => {
    const res = await request(app)
      .post(`/screenings/${testScreeningId}/mcq-attempts`)
      .set('x-api-key', testApiKey)
      .send({
        questionId: 'mcq_cpap_pressure',
        selectedOption: '5 cm H2O',
        isCorrect: true,
      });

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
  });

  it('PATCH /screenings/:id/status updates screening status', async () => {
    const res = await request(app)
      .patch(`/screenings/${testScreeningId}/status`)
      .set('x-api-key', testApiKey)
      .send({
        status: 'completed',
      });

    assert.equal(res.status, 200);
    assert.equal(res.body.status, 'completed');
  });

  it('POST /chat-logs logs grounded query and answer in separate collection', async () => {
    const chatLogId = '33333333-3333-4333-8333-333333333333';
    const res = await request(app)
      .post('/chat-logs')
      .set('x-api-key', testApiKey)
      .send({
        _id: chatLogId,
        sessionId: testSessionId,
        userQuery: 'What is caffeine citrate loading dose?',
        extractedAnswer: 'Loading dose: 20 mg/kg IV/oral',
        chunkIds: ['chunk_caffeine_1'],
        source: {
          document: 'respiratory_distress_neonates_stw.pdf',
          page: 1,
          section: 'Algorithm',
        },
        found: true,
        retrieverType: 'bm25_pure_dart',
      });

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
  });

  it('Chat Log: stores a not-covered answer with no source', async () => {
    const chatLogId = '44444444-4444-4444-8444-444444444444';
    const res = await request(app)
      .post('/chat-logs')
      .set('x-api-key', testApiKey)
      .send({
        _id: chatLogId,
        sessionId: testSessionId,
        userQuery: 'Phototherapy threshold for neonatal jaundice',
        extractedAnswer: 'This information is not covered in the approved STW documents.',
        chunkIds: [],
        source: null,
        found: false,
        retrieverType: 'stw_answerer_v1:notCovered',
      });
    assert.equal(res.status, 200);

    const stored = await getChatLogsCollection().findOne({ _id: chatLogId });
    assert.equal(stored.source, null);
    assert.equal(stored.found, false);
  });

  it('Screening timing: saves duration and preserves first completion on retry', async () => {
    const id = '77777777-7777-4777-8777-777777777771';
    const startedAt = '2026-10-15T10:00:00.000Z';
    const completedAt = '2026-10-15T10:00:42.123Z';
    const created = await request(app).put(`/screenings/${id}`)
      .set('x-api-key', testApiKey)
      .send({ sessionId: testSessionId, diseaseCode: 'rop', startedAt });
    assert.equal(created.status, 200);
    assert.equal((await getScreeningsCollection().findOne({ _id: id })).durationMs, null);
    const completed = await request(app).patch(`/screenings/${id}/status`)
      .set('x-api-key', testApiKey).send({ status: 'completed', completedAt });
    assert.equal(completed.status, 200);
    await Promise.all([43, 50].map((seconds) => request(app)
      .patch(`/screenings/${id}/status`).set('x-api-key', testApiKey)
      .send({ status: 'completed', completedAt: `2026-10-15T10:00:${seconds}.000Z` })));
    const saved = await request(app).get(`/export/screenings/${id}`).set('x-api-key', testExportKey);
    assert.equal(saved.status, 200);
    assert.equal(saved.body.startedAt, startedAt);
    assert.equal(saved.body.completedAt, completedAt);
    assert.equal(saved.body.durationMs, 42123);
    const exported = await request(app).get('/export/screenings?diseaseCode=rop')
      .set('x-api-key', testExportKey);
    assert.equal(exported.body.data.find((row) => row._id === id).durationMs, 42123);
  });

  it('Screening timing: rejects completion before start without mutating the record', async () => {
    const id = '77777777-7777-4777-8777-777777777772';
    await request(app).put(`/screenings/${id}`).set('x-api-key', testApiKey)
      .send({ sessionId: testSessionId, diseaseCode: 'rop', startedAt: '2026-10-15T10:00:00.000Z' });
    const result = await request(app).patch(`/screenings/${id}/status`)
      .set('x-api-key', testApiKey)
      .send({ status: 'completed', completedAt: '2026-10-15T09:59:59.000Z' });
    assert.equal(result.status, 400);
    const saved = await getScreeningsCollection().findOne({ _id: id });
    assert.equal(saved.status, 'in_progress');
    assert.equal(saved.completedAt, null);
    assert.equal(saved.durationMs, null);
    const invalidPut = await request(app).put(`/screenings/${id}`)
      .set('x-api-key', testApiKey).send({ sessionId: testSessionId, diseaseCode: 'rop',
        startedAt: '2026-10-15T10:00:00.000Z', completedAt: '2026-10-15T09:00:00.000Z' });
    assert.equal(invalidPut.status, 400);
  });

  // The client key ships inside the app, so it must never read data back.
  for (const path of [
    `/sessions/${testSessionId}`,
    '/screenings',
    `/screenings?sessionId=${testSessionId}`,
    `/screenings/${testScreeningId}`,
    '/chat-logs',
    `/chat-logs?sessionId=${testSessionId}`,
    '/audit-events',
  ]) {
    it(`Client key: GET ${path} is refused (write-only)`, async () => {
      for (const key of [testApiKey, testExportKey, null]) {
        let req = request(app).get(path);
        if (key) req = req.set('x-api-key', key);
        const res = await req;
        assert.equal(res.status, 405, `key=${key}`);
        assert.equal(res.body.error, 'MethodNotAllowed');
        assert.equal(JSON.stringify(res.body).includes(testScreeningId), false);
      }
    });
  }

  it('PUT /screenings/:id/decision stores the latest decision and exports it', async () => {
    const decision = (category) => ({
      decision: {
        topic: 'triage',
        category,
        triggers: ['HR 210/min (>200/min)'],
        flaggedCards: [{ id: 'circulation', because: ['HR 210/min (>200/min)'] }],
        computedDoses: [],
      },
      recordedAt: '2026-10-17T10:00:00.000Z',
    });
    const first = await request(app)
      .put(`/screenings/${testScreeningId}/decision`)
      .set('x-api-key', testApiKey)
      .send(decision('PRIORITY'));
    assert.equal(first.status, 200);
    const second = await request(app)
      .put(`/screenings/${testScreeningId}/decision`)
      .set('x-api-key', testApiKey)
      .send(decision('EMERGENCY'));
    assert.equal(second.status, 200);

    const doc = await getScreeningsCollection().findOne({ _id: testScreeningId });
    assert.equal(doc.decision.category, 'EMERGENCY');
    assert.deepEqual(doc.decision.triggers, ['HR 210/min (>200/min)']);

    const exported = await request(app)
      .get(`/export/screenings/${testScreeningId}`)
      .set('x-api-key', testExportKey);
    assert.equal(exported.status, 200);
    assert.equal(exported.body.decision.category, 'EMERGENCY');
  });

  it('PUT /screenings/:id/decision: unknown screening is 404, PHI keys are 400', async () => {
    const missing = await request(app)
      .put('/screenings/99999999-9999-4999-8999-999999999999/decision')
      .set('x-api-key', testApiKey)
      .send({ decision: { category: 'EMERGENCY' } });
    assert.equal(missing.status, 404);
    const phi = await request(app)
      .put(`/screenings/${testScreeningId}/decision`)
      .set('x-api-key', testApiKey)
      .send({ decision: { patient_name: 'Baby X' } });
    assert.equal(phi.status, 400);
  });

  it('POST /audit-events stores a batch once, even when resent', async () => {
    const events = [
      {
        _id: '33333333-3333-4333-8333-333333333331',
        sessionId: testSessionId,
        type: 'screen_view',
        screen: '/workflow',
        occurredAt: '2026-10-17T10:00:00.000Z',
      },
      {
        _id: '33333333-3333-4333-8333-333333333332',
        sessionId: testSessionId,
        type: 'stw_pdf_opened',
        screen: '/workflow',
        data: { regionId: 'triage_hypoglycemia', origin: 'triage_card:hypoglycemia' },
        occurredAt: '2026-10-17T10:00:05.000Z',
      },
    ];
    for (let i = 0; i < 2; i++) {
      const res = await request(app).post('/audit-events').set('x-api-key', testApiKey).send({ events });
      assert.equal(res.status, 200);
      assert.equal(res.body.inserted, i === 0 ? 2 : 0);
    }

    const exported = await request(app)
      .get(`/export/audit-events?sessionId=${testSessionId}&type=stw_pdf_opened`)
      .set('x-api-key', testExportKey);
    assert.equal(exported.status, 200);
    assert.equal(exported.body.total, 1);
    assert.equal(exported.body.data[0].data.regionId, 'triage_hypoglycemia');
  });

  it('POST /audit-events rejects PHI keys and malformed events', async () => {
    const base = {
      _id: '33333333-3333-4333-8333-333333333339',
      type: 'tap',
      occurredAt: '2026-10-17T10:00:00.000Z',
    };
    const phi = await request(app)
      .post('/audit-events')
      .set('x-api-key', testApiKey)
      .send({ events: [{ ...base, data: { mrn: '123' } }] });
    assert.equal(phi.status, 400);
    const unknownField = await request(app)
      .post('/audit-events')
      .set('x-api-key', testApiKey)
      .send({ events: [{ ...base, freeText: 'x' }] });
    assert.equal(unknownField.status, 400);
    const empty = await request(app).post('/audit-events').set('x-api-key', testApiKey).send({ events: [] });
    assert.equal(empty.status, 400);
  });

  it('POST /chat-logs stores the clinical context', async () => {
    const res = await request(app)
      .post('/chat-logs')
      .set('x-api-key', testApiKey)
      .send({
        _id: '55555555-5555-4555-8555-555555555555',
        sessionId: testSessionId,
        userQuery: 'shock bolus',
        extractedAnswer: 'IV NS 10 mL/kg',
        found: true,
        context: { selected: ['triage'], triageCategory: 'EMERGENCY' },
      });
    assert.equal(res.status, 200);
    const doc = await getChatLogsCollection().findOne({ _id: '55555555-5555-4555-8555-555555555555' });
    assert.equal(doc.context.triageCategory, 'EMERGENCY');
  });

  it('Client key: HEAD on client routes is refused too', async () => {
    const res = await request(app).head(`/screenings/${testScreeningId}`).set('x-api-key', testApiKey);
    assert.equal(res.status, 405);
  });

  it('Client key: writes still work after reads are closed', async () => {
    const res = await request(app)
      .put(`/screenings/${testScreeningId}/responses/rd_rr`)
      .set('x-api-key', testApiKey)
      .send({ value: 64 });
    assert.equal(res.status, 200);
  });

  for (const path of [
    `/export/sessions/${testSessionId}`,
    `/export/screenings/${testScreeningId}`,
    '/export/chat-logs',
    '/export/audit-events',
    '/export/stats',
  ]) {
    it(`Export: GET ${path} rejects the write key and a missing key`, async () => {
      const withWriteKey = await request(app).get(path).set('x-api-key', testApiKey);
      assert.equal(withWriteKey.status, 403);
      const noKey = await request(app).get(path);
      assert.equal(noKey.status, 401);
    });
  }

  it('Export: session read omits the per-device session token', async () => {
    const res = await request(app)
      .get(`/export/sessions/${testSessionId}`)
      .set('x-api-key', testExportKey);
    assert.equal(res.status, 200);
    assert.equal(res.body._id, testSessionId);
    assert.equal('sessionToken' in res.body, false);
  });

  it('Export: screenings filter by sessionId; single screening by id', async () => {
    const list = await request(app)
      .get(`/export/screenings?sessionId=${testSessionId}`)
      .set('x-api-key', testExportKey);
    assert.equal(list.status, 200);
    assert.ok(list.body.data.length >= 1);
    assert.ok(list.body.data.every((row) => row.sessionId === testSessionId));

    const one = await request(app)
      .get(`/export/screenings/${testScreeningId}`)
      .set('x-api-key', testExportKey);
    assert.equal(one.status, 200);
    assert.equal(one.body._id, testScreeningId);

    const missing = await request(app)
      .get('/export/screenings/99999999-9999-4999-8999-999999999999')
      .set('x-api-key', testExportKey);
    assert.equal(missing.status, 404);

    const badFilter = await request(app)
      .get('/export/screenings?sessionId=not-a-uuid')
      .set('x-api-key', testExportKey);
    assert.equal(badFilter.status, 400);
  });

  it('Export: chat logs filter by sessionId', async () => {
    const logId = '88888888-8888-4888-8888-888888888881';
    await request(app).post('/chat-logs').set('x-api-key', testApiKey).send({
      _id: logId,
      sessionId: testSessionId,
      userQuery: 'surfactant dose',
      extractedAnswer: 'Give surfactant as per the STW.',
      found: true,
    });
    const res = await request(app)
      .get(`/export/chat-logs?sessionId=${testSessionId}`)
      .set('x-api-key', testExportKey);
    assert.equal(res.status, 200);
    assert.ok(res.body.data.some((row) => row._id === logId));
    assert.ok(res.body.data.every((row) => row.sessionId === testSessionId));
  });

  it('Export: rejects export access without export key', async () => {
    const res = await request(app).get('/export/screenings');
    assert.equal(res.status, 401);
  });

  it('Export: the export route rejects a write key', async () => {
    const res = await request(app)
      .get('/export/screenings')
      .set('x-api-key', testApiKey); // Write key passed to export route!

    assert.equal(res.status, 403);
    assert.equal(res.body.error, 'Forbidden');
  });

  it('Export: returns paginated de-identified screenings with export key', async () => {
    const res = await request(app)
      .get('/export/screenings?diseaseCode=respiratory_distress&limit=10')
      .set('x-api-key', testExportKey);

    assert.equal(res.status, 200);
    assert.equal(res.body.limit, 10);
    assert.ok(res.body.data.length >= 1);
    assert.equal(res.body.data[0]._id, testScreeningId);
    assert.ok(Array.isArray(res.body.data[0].responses));
  });
  it('Export: GET /export/stats aggregates the stored data', async () => {
    const res = await request(app).get('/export/stats').set('x-api-key', testExportKey);
    assert.equal(res.status, 200);
    const { totals } = res.body;
    assert.ok(totals.sessions >= 1);
    assert.ok(totals.screenings >= 1);
    assert.ok(totals.completedScreenings <= totals.screenings);
    assert.ok(totals.chatLogsNotFound <= totals.chatLogs);
    assert.ok(res.body.screeningsByDisease.some((d) => d.diseaseCode === 'respiratory_distress'));
    assert.ok(res.body.triageCategories.some((c) => c.category === 'EMERGENCY'));
    assert.ok(res.body.auditEventsByType.some((t) => t.type === 'stw_pdf_opened'));
    assert.deepEqual(res.body.topStwRegions.find((r) => r.regionId === 'triage_hypoglycemia'), {
      regionId: 'triage_hypoglycemia',
      count: 1,
    });
    assert.ok(Array.isArray(res.body.daily.screenings));
    assert.equal(JSON.stringify(res.body).includes('token-123'), false);
  });

  it('Export: GET /export/stats applies from/to and rejects unknown params', async () => {
    const future = await request(app)
      .get('/export/stats?from=2099-01-01T00:00:00.000Z')
      .set('x-api-key', testExportKey);
    assert.equal(future.status, 200);
    assert.equal(future.body.totals.screenings, 0);
    assert.equal(future.body.totals.auditEvents, 0);
    assert.deepEqual(future.body.screeningsByDisease, []);

    const bad = await request(app).get('/export/stats?collection=sessions').set('x-api-key', testExportKey);
    assert.equal(bad.status, 400);
  });
});
