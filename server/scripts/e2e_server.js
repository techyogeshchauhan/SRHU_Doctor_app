// Runs the real REST API for the app's end-to-end sync test
// (test/e2e_mongo_sync_test.dart). Prints "READY <port>" once listening.
//
//   node scripts/e2e_server.js [port]           # in-memory MongoDB
//   node scripts/e2e_server.js [port] --atlas   # Atlas from server/.env, but a
//                                               # separate database E2E_DB_NAME
//                                               # (default stw_neo_e2e), never
//                                               # the production one
import { createApp } from '../src/app.js';
import { config } from '../src/config.js';
import { closeDatabase, connectToDatabase } from '../src/db.js';

const port = parseInt(process.argv[2] || '0', 10);
const atlas = process.argv.includes('--atlas');

let mongod = null;
if (atlas) {
  const dbName = process.env.E2E_DB_NAME || 'stw_neo_e2e';
  if (dbName === config.dbName) {
    console.error(`Refusing to run end-to-end tests against the production database "${dbName}".`);
    process.exit(1);
  }
  await connectToDatabase(config.getMongoUri(), dbName);
} else {
  const { MongoMemoryServer } = await import('mongodb-memory-server');
  mongod = await MongoMemoryServer.create();
  await connectToDatabase(mongod.getUri(), config.dbName);
}

const server = createApp().listen(port, '127.0.0.1', () => {
  console.log(`READY ${server.address().port}`);
});

async function shutdown() {
  server.close();
  await closeDatabase();
  await mongod?.stop();
  process.exit(0);
}
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
