import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Load .env from server directory
dotenv.config({ path: path.resolve(__dirname, '../.env') });

/**
 * Builds the MongoDB connection string dynamically from discrete environment variables.
 * Fails fast with a clear error message (without leaking secrets) if any required variable is missing.
 */
export function buildMongoUri(env = process.env) {
  // Allow test override with in-memory URI
  if (env.TEST_MONGODB_URI) {
    return env.TEST_MONGODB_URI;
  }

  const username = env.MONGODB_USERNAME?.trim();
  const password = env.MONGODB_PASSWORD?.trim();
  const host = env.MONGODB_HOST?.trim();
  const dbName = env.DB_NAME?.trim() || 'stw_neo';
  const options = env.MONGODB_OPTIONS?.trim() || 'retryWrites=true&w=majority';

  const missing = [];
  if (!username) missing.push('MONGODB_USERNAME');
  if (!password) missing.push('MONGODB_PASSWORD');
  if (!host) missing.push('MONGODB_HOST');

  if (missing.length > 0) {
    throw new Error(
      `[Startup Error] Missing required MongoDB environment variable(s): ${missing.join(', ')}. ` +
      `Please provide them in server/.env (see server/.env.example).`
    );
  }

  const encodedUser = encodeURIComponent(username);
  const encodedPass = encodeURIComponent(password);

  return `mongodb+srv://${encodedUser}:${encodedPass}@${host}/${dbName}?${options}`;
}

export const config = {
  port: parseInt(process.env.PORT || '4000', 10),
  dbName: process.env.DB_NAME?.trim() || 'stw_neo',
  apiKeys: (process.env.API_KEYS || 'stw_dev_client_key_12345')
    .split(',')
    .map((k) => k.trim())
    .filter(Boolean),
  exportApiKey: (process.env.EXPORT_API_KEY || process.env.EXPORT_API_KEYS || 'stw_research_export_key_67890').trim(),
  allowedOrigins: (process.env.ALLOWED_ORIGINS || '')
    .split(',')
    .map((o) => o.trim())
    .filter(Boolean),
  getMongoUri: (env = process.env) => buildMongoUri(env),
};
