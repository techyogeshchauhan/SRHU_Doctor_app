import { MongoClient } from 'mongodb';
import { config } from './config.js';

let client = null;
let db = null;

/**
 * Connects to MongoDB Atlas using the URI generated from environment variables.
 * Safe logging: Never logs credentials or connection strings.
 */
export async function connectToDatabase(customUri = null, customDbName = null) {
  if (client && db) {
    return db;
  }

  const uri = customUri || config.getMongoUri();
  const dbName = customDbName || config.dbName;

  client = new MongoClient(uri, {
    maxPoolSize: 20,
    minPoolSize: 2,
    serverSelectionTimeoutMS: 5000,
  });

  await client.connect();
  db = client.db(dbName);

  // Initialize indexes idempotently
  await initIndexes(db);

  // Log ONLY database name - NEVER the URI
  console.log(`Connected to MongoDB (db: ${dbName})`);

  return db;
}

export async function initIndexes(databaseInstance) {
  const targetDb = databaseInstance || db;
  if (!targetDb) return;

  const screenings = targetDb.collection('screenings');
  await screenings.createIndex({ sessionId: 1 }, { name: 'idx_screenings_session_id' });
  await screenings.createIndex(
    { diseaseCode: 1, startedAt: 1 },
    { name: 'idx_screenings_disease_started' }
  );

  const chatLogs = targetDb.collection('chatLogs');
  await chatLogs.createIndex({ sessionId: 1 }, { name: 'idx_chat_logs_session_id' });
  await chatLogs.createIndex({ createdAt: 1 }, { name: 'idx_chat_logs_created_at' });

  const sessions = targetDb.collection('sessions');
  await sessions.createIndex({ createdAt: 1 }, { name: 'idx_sessions_created_at' });

  const diseases = targetDb.collection('diseases');
  await diseases.createIndex({ code: 1 }, { unique: true, name: 'idx_diseases_code_unique' });
}

export function getDb() {
  if (!db) {
    throw new Error('Database not connected. Call connectToDatabase() first.');
  }
  return db;
}

export function getSessionsCollection() {
  return getDb().collection('sessions');
}

export function getScreeningsCollection() {
  return getDb().collection('screenings');
}

export function getChatLogsCollection() {
  return getDb().collection('chatLogs');
}

export function getDiseasesCollection() {
  return getDb().collection('diseases');
}

export async function closeDatabase() {
  if (client) {
    await client.close();
    client = null;
    db = null;
  }
}
