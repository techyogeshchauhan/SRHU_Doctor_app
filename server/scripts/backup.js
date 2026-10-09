import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { config } from '../src/config.js';
import { closeDatabase, connectToDatabase, getDb } from '../src/db.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function runBackup() {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const backupDir = path.resolve(__dirname, `../backups/backup_${timestamp}`);

  try {
    console.log(`[Backup] Starting MongoDB Atlas backup to: ${backupDir}`);
    fs.mkdirSync(backupDir, { recursive: true });

    await connectToDatabase();
    const db = getDb();

    const collections = ['sessions', 'screenings', 'chatLogs', 'diseases'];

    for (const colName of collections) {
      console.log(`[Backup] Exporting collection: ${colName}...`);
      const col = db.collection(colName);
      const docs = await col.find({}).toArray();

      const outPath = path.join(backupDir, `${colName}.json`);
      fs.writeFileSync(outPath, JSON.stringify(docs, null, 2), 'utf-8');
      console.log(`  ✓ Exported ${docs.length} documents to ${colName}.json`);
    }

    const summary = {
      backupTimestamp: new Date().toISOString(),
      database: config.dbName,
      collectionsExported: collections,
    };
    fs.writeFileSync(
      path.join(backupDir, 'backup_summary.json'),
      JSON.stringify(summary, null, 2),
      'utf-8'
    );

    console.log(`[Backup] Weekly backup completed successfully at: ${backupDir}`);
  } catch (err) {
    console.error('[Backup] Backup failed:', err);
    process.exit(1);
  } finally {
    await closeDatabase();
  }
}

runBackup();
