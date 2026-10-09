import { createApp } from './app.js';
import { config } from './config.js';
import { closeDatabase, connectToDatabase } from './db.js';

async function bootstrap() {
  try {
    // connectToDatabase uses the env-built URI and logs "Connected to MongoDB (db: <DB_NAME>)"
    await connectToDatabase();

    const app = createApp();

    const server = app.listen(config.port, config.host, () => {
      console.log(`[Server] REST API listening on ${config.host ?? 'all interfaces'}, port ${config.port}`);
      console.log(`[Server] Health check available at http://localhost:${config.port}/health`);
    });

    const shutdown = async () => {
      console.log('[Server] Shutting down gracefully...');
      server.close(async () => {
        await closeDatabase();
        console.log('[Server] HTTP server and database connection closed.');
        process.exit(0);
      });
    };

    process.on('SIGINT', shutdown);
    process.on('SIGTERM', shutdown);
  } catch (err) {
    // Fail fast with clear message without leaking secrets
    console.error(`[Server] Fatal startup error: ${err.message}`);
    process.exit(1);
  }
}

bootstrap();
