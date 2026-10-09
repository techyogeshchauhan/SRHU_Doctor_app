import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';
import { MongoMemoryServer } from 'mongodb-memory-server';
import request from 'supertest';

import { createApp } from '../src/app.js';
import { buildMongoUri, config } from '../src/config.js';
import { closeDatabase, connectToDatabase, getScreeningsCollection } from '../src/db.js';

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
        assert.ok(!err.message.includes('sBm4RQLjpzcOb6jx'));
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
});
