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

// The public development keys from .env.example are refused in production:
// a server started without real keys would accept anyone.
const DEV_KEYS = ['stw_dev_client_key_12345', 'stw_mobile_app_prod_key', 'stw_research_export_key_67890'];
const isProduction = process.env.NODE_ENV === 'production';

function keysFrom(value, devDefault, name) {
  const keys = (value || (isProduction ? '' : devDefault))
    .split(',')
    .map((k) => k.trim())
    .filter(Boolean);
  if (isProduction && (keys.length === 0 || keys.some((k) => DEV_KEYS.includes(k)))) {
    throw new Error(
      `[Startup Error] ${name} must be set to new random keys in production (see server/.env.example).`
    );
  }
  return keys;
}

export const config = {
  port: parseInt(process.env.PORT || '4000', 10),
  // Interface to listen on. 127.0.0.1 on a shared server: reachable only
  // through nginx, never directly from the internet. Unset: all interfaces.
  host: process.env.HOST?.trim() || undefined,
  dbName: process.env.DB_NAME?.trim() || 'stw_neo',
  apiKeys: keysFrom(process.env.API_KEYS, 'stw_dev_client_key_12345', 'API_KEYS'),
  exportApiKey: keysFrom(
    process.env.EXPORT_API_KEY || process.env.EXPORT_API_KEYS,
    'stw_research_export_key_67890',
    'EXPORT_API_KEY'
  )[0],
  allowedOrigins: (process.env.ALLOWED_ORIGINS || '')
    .split(',')
    .map((o) => o.trim())
    .filter(Boolean),
  // Requests per minute per client IP.
  rateLimitPerMinute: parseInt(process.env.RATE_LIMIT_PER_MINUTE || '120', 10),
  // Set when behind a reverse proxy (e.g. "1" for one nginx hop) so rate
  // limiting sees each client's IP instead of the proxy's.
  trustProxy: process.env.TRUST_PROXY?.trim() || '',
  getMongoUri: (env = process.env) => buildMongoUri(env),
};
