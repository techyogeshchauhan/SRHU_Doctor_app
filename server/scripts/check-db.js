// Read-only check of the MongoDB Atlas database configured in server/.env:
// connects, pings, and prints each collection's document count and the
// newest document's field names and time. Never prints credentials or
// document contents.
//
//   node scripts/check-db.js            # DB_NAME from server/.env
//   node scripts/check-db.js stw_neo_e2e
import { MongoClient } from 'mongodb';
import { config } from '../src/config.js';

const dbName = process.argv[2] || config.dbName;

function redact(message) {
  return message.replace(/mongodb(\+srv)?:\/\/[^@\s]+@/g, 'mongodb$1://<credentials>@');
}

let client;
try {
  client = new MongoClient(config.getMongoUri(), { serverSelectionTimeoutMS: 10000 });
  await client.connect();
  const db = client.db(dbName);
  await db.command({ ping: 1 });
  console.log(`Connected to Atlas, database "${dbName}".`);

  const collections = (await db.listCollections().toArray()).map((c) => c.name).sort();
  if (collections.length === 0) console.log('No collections yet (nothing stored).');
  for (const name of collections) {
    const col = db.collection(name);
    const count = await col.countDocuments();
    const [latest] = await col.find().sort({ createdAt: -1, _id: -1 }).limit(1).toArray();
    const when = latest?.createdAt ?? latest?.startedAt ?? latest?.updatedAt;
    console.log(`- ${name}: ${count} document(s)`);
    if (latest) {
      console.log(`    newest: ${when instanceof Date ? when.toISOString() : 'n/a'}`);
      console.log(`    fields: ${Object.keys(latest).join(', ')}`);
    }
  }
} catch (err) {
  console.error(`ERROR: ${err.name}: ${redact(err.message)}`);
  process.exitCode = 1;
} finally {
  await client?.close();
}
