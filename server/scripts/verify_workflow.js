import { randomUUID } from 'crypto';
import { MongoMemoryServer } from 'mongodb-memory-server';
import request from 'supertest';
import { createApp } from '../src/app.js';
import { config } from '../src/config.js';
import { closeDatabase, connectToDatabase, getChatLogsCollection, getScreeningsCollection, getSessionsCollection } from '../src/db.js';

async function runVerification() {
  console.log('================================================================');
  console.log('   STW NEO: REST API & MONGODB INTEGRATION VERIFICATION SCRIPT   ');
  console.log('================================================================\n');

  let mongod = null;
  let uri = null;

  try {
    uri = config.getMongoUri();
    console.log('[Setup] Connecting to MongoDB Atlas cluster...');
  } catch (err) {
    console.log(`[Setup] Atlas credentials incomplete in server/.env (${err.message}).`);
    console.log('[Setup] Starting in-memory MongoDB environment for self-contained verification...');
    mongod = await MongoMemoryServer.create();
    uri = mongod.getUri();
  }

  await connectToDatabase(uri, config.dbName);
  const app = createApp();
  const apiKey = config.apiKeys[0] || 'stw_dev_client_key_12345';

  const sessionId = randomUUID();
  const sessionToken = randomUUID();
  const rdScreeningId = randomUUID();
  const ropScreeningId = randomUUID();

  // 1. Create Clinical Session
  console.log('1. Creating Clinical Session...');
  const sessionRes = await request(app)
    .post('/sessions')
    .set('x-api-key', apiKey)
    .send({
      _id: sessionId,
      sessionToken: sessionToken,
      facilityName: 'SRHU Neonatal Care Unit',
      platform: 'web',
      appVersion: '0.1.0+1',
      status: 'in_progress',
    });
  console.log(`   Session Created: HTTP ${sessionRes.status} -> ID: ${sessionId}`);

  // 2. Respiratory Distress Screening Workflow
  console.log('\n2. Executing Respiratory Distress Screening Workflow...');
  await request(app)
    .put(`/screenings/${rdScreeningId}`)
    .set('x-api-key', apiKey)
    .send({
      sessionId,
      diseaseCode: 'respiratory_distress',
      progressState: 'in_progress',
      isEligible: true,
      status: 'in_progress',
    });

  // Question Responses for RD
  const rdQuestions = [
    { qId: 'gestational_age', val: 31, unit: 'weeks', mode: 'slider' },
    { qId: 'silverman_score', val: 5, unit: 'score', mode: 'score' },
    { qId: 'grunting', val: 'present', mode: 'radio' },
  ];

  for (const q of rdQuestions) {
    await request(app)
      .put(`/screenings/${rdScreeningId}/responses/${q.qId}`)
      .set('x-api-key', apiKey)
      .send({ value: q.val, unit: q.unit, inputMode: q.mode });
    console.log(`   Answered RD Question: ${q.qId} = ${q.val}`);
  }

  // Findings for RD
  await request(app)
    .post(`/screenings/${rdScreeningId}/findings`)
    .set('x-api-key', apiKey)
    .send({
      findings: [
        {
          type: 'respiratory_distress_moderate',
          title: 'Moderate-to-Severe Respiratory Distress (SAS Score >= 4)',
          severity: 'moderate',
          recommendations: ['Initiate CPAP 5-6 cm H2O immediately', 'Administer caffeine citrate loading dose (20 mg/kg)'],
          stwReference: 'ICMR Respiratory Distress STW Page 1 Algorithm',
        },
      ],
    });
  console.log('   Recorded RD Clinical Findings.');

  // MCQ attempt for RD
  await request(app)
    .post(`/screenings/${rdScreeningId}/mcq-attempts`)
    .set('x-api-key', apiKey)
    .send({
      questionId: 'rd_mcq_cpap_pressure',
      selectedOption: '5 cm H2O',
      isCorrect: true,
    });
  console.log('   Recorded RD MCQ Attempt.');

  // Complete RD Screening
  await request(app)
    .patch(`/screenings/${rdScreeningId}/status`)
    .set('x-api-key', apiKey)
    .send({ status: 'completed' });
  console.log('   Marked RD Screening Completed.');

  // 3. ROP Screening Workflow
  console.log('\n3. Executing Retinopathy of Prematurity (ROP) Screening Workflow...');
  await request(app)
    .put(`/screenings/${ropScreeningId}`)
    .set('x-api-key', apiKey)
    .send({
      sessionId,
      diseaseCode: 'rop',
      progressState: 'in_progress',
      isEligible: true,
      status: 'in_progress',
    });

  const ropQuestions = [
    { qId: 'gestational_age', val: 29, unit: 'weeks', mode: 'slider' },
    { qId: 'birth_weight', val: 1100, unit: 'grams', mode: 'number' },
    { qId: 'oxygen_exposure', val: 'yes', mode: 'toggle' },
    { qId: 'right_eye_zone', val: 'Zone II', mode: 'dropdown' },
    { qId: 'right_eye_stage', val: 'Stage 3', mode: 'dropdown' },
    { qId: 'plus_disease', val: 'present', mode: 'toggle' },
  ];

  for (const q of ropQuestions) {
    await request(app)
      .put(`/screenings/${ropScreeningId}/responses/${q.qId}`)
      .set('x-api-key', apiKey)
      .send({ value: q.val, unit: q.unit, inputMode: q.mode });
    console.log(`   Answered ROP Question: ${q.qId} = ${q.val}`);
  }

  // Findings for ROP
  await request(app)
    .post(`/screenings/${ropScreeningId}/findings`)
    .set('x-api-key', apiKey)
    .send({
      findings: [
        {
          type: 'rop_treatment_requiring',
          title: 'Treatment-Requiring ROP (Type 1 ROP: Zone II Stage 3 with Plus Disease)',
          severity: 'urgent',
          recommendations: ['Laser photocoagulation or anti-VEGF within 48-72 hours', 'Consult vitreoretinal specialist'],
          stwReference: 'ICMR Retinopathy of Prematurity STW Section 2.6',
        },
      ],
    });
  console.log('   Recorded ROP Clinical Findings.');

  // MCQ attempt for ROP
  await request(app)
    .post(`/screenings/${ropScreeningId}/mcq-attempts`)
    .set('x-api-key', apiKey)
    .send({
      questionId: 'rop_mcq_timing',
      selectedOption: '4 weeks of life or 30-34 weeks PMA',
      isCorrect: true,
    });
  console.log('   Recorded ROP MCQ Attempt.');

  // Complete ROP Screening
  await request(app)
    .patch(`/screenings/${ropScreeningId}/status`)
    .set('x-api-key', apiKey)
    .send({ status: 'completed' });
  console.log('   Marked ROP Screening Completed.');

  // 4. Ask 3 Chatbot Queries
  console.log('\n4. Logging 3 Extractive Chatbot Queries Grounded in STWs...');
  const chatQueries = [
    {
      query: 'What is the indication and dosage of caffeine citrate in respiratory distress?',
      answer: 'Start caffeine citrate: Loading dose 20 mg/kg IV/oral, followed by maintenance 5-10 mg/kg/day.',
      source: { document: 'respiratory_distress_neonates_stw.pdf', page: 1, section: 'Algorithm' },
      chunkIds: ['rd_chunk_caffeine'],
    },
    {
      query: 'What are the criteria for screening in retinopathy of prematurity?',
      answer: 'All preterm neonates born at <34 weeks gestation and/or birth weight <2000 grams must be screened.',
      source: { document: 'retinopathy_of_prematurity_stw.pdf', page: 2, section: 'Eligibility' },
      chunkIds: ['rop_chunk_eligibility'],
    },
    {
      query: 'What is Silverman Anderson score for grunting?',
      answer: 'Grade 0: None, Grade 1: Audible with stethoscope, Grade 2: Audible with naked ear.',
      source: { document: 'respiratory_distress_neonates_stw.pdf', page: 3, section: 'Scoring Table' },
      chunkIds: ['rd_chunk_sas_grunting'],
    },
  ];

  for (const c of chatQueries) {
    const chatLogId = randomUUID();
    await request(app)
      .post('/chat-logs')
      .set('x-api-key', apiKey)
      .send({
        _id: chatLogId,
        sessionId,
        userQuery: c.query,
        extractedAnswer: c.answer,
        chunkIds: c.chunkIds,
        source: c.source,
        found: true,
        retrieverType: 'bm25_pure_dart',
      });
    console.log(`   Logged STW Query: "${c.query.substring(0, 40)}..."`);
  }

  // 5. Print Resulting MongoDB Documents
  console.log('\n================================================================');
  console.log('               PERSISTED MONGODB DOCUMENTS                      ');
  console.log('================================================================\n');

  const sessionsCol = getSessionsCollection();
  const screeningsCol = getScreeningsCollection();
  const chatLogsCol = getChatLogsCollection();

  const savedSession = await sessionsCol.findOne({ _id: sessionId });
  console.log('--- SESSION DOCUMENT ---');
  console.log(JSON.stringify(savedSession, null, 2));

  const savedScreenings = await screeningsCol.find({ sessionId }).toArray();
  console.log('\n--- SCREENINGS DOCUMENTS (Count: ' + savedScreenings.length + ') ---');
  console.log(JSON.stringify(savedScreenings, null, 2));

  const savedChatLogs = await chatLogsCol.find({ sessionId }).toArray();
  console.log('\n--- CHAT LOGS DOCUMENTS (Count: ' + savedChatLogs.length + ') ---');
  console.log(JSON.stringify(savedChatLogs, null, 2));

  // 6. Test Offline Mode and Idempotence
  console.log('\n================================================================');
  console.log('   6. TESTING OFFLINE RECONNECT & IDEMPOTENT UPSERT BEHAVIOR    ');
  console.log('================================================================\n');

  console.log('Simulating offline client answering "gestational_age" with multiple retries...');
  // Simulate 3 repeated submissions of gestational_age for rdScreeningId with updated value
  for (let i = 1; i <= 3; i++) {
    const putRes = await request(app)
      .put(`/screenings/${rdScreeningId}/responses/gestational_age`)
      .set('x-api-key', apiKey)
      .send({
        value: 32, // Final confirmed value
        unit: 'weeks',
        inputMode: 'slider',
      });
    console.log(`   Attempt ${i} flush: HTTP ${putRes.status}`);
  }

  const updatedDoc = await screeningsCol.findOne({ _id: rdScreeningId });
  const gaResponses = updatedDoc.responses.filter((r) => r.questionId === 'gestational_age');
  console.log(`\nVerification Check:`);
  console.log(`   Total 'gestational_age' entries in responses array: ${gaResponses.length} (Expected: 1)`);
  console.log(`   Final stored value: ${gaResponses[0].value} ${gaResponses[0].unit}`);

  if (gaResponses.length === 1 && gaResponses[0].value === 32) {
    console.log('\n>>> SUCCESS: Exactly ONE document entry exists per answer. Zero duplicates generated! <<<\n');
  } else {
    throw new Error('Idempotence check failed: Duplicate entries or wrong value found.');
  }

  await closeDatabase();
  if (mongod) {
    await mongod.stop();
  }

  console.log('All verification stages passed successfully!');
}

runVerification().catch((err) => {
  console.error('Verification script error:', err);
  process.exit(1);
});
