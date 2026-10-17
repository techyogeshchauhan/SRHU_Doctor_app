import { config } from '../config.js';

/**
 * Validates x-api-key against configured client write API_KEYS.
 * Missing or wrong key returns 401.
 */
export function apiKeyAuth(req, res, next) {
  const apiKey = req.header('x-api-key');

  if (!apiKey || !config.apiKeys.includes(apiKey)) {
    return res.status(401).json({
      error: 'Unauthorized',
      message: 'Missing or invalid x-api-key header.',
    });
  }

  req.auth = {
    type: 'apiKey',
    key: apiKey,
    role: 'client_write',
  };

  next();
}

/**
 * The client key ships inside the app (web bundle, APK), so it must be
 * treated as public: it may create and update records but never read them.
 * Reads go through /export with the export key. Runs before apiKeyAuth so a
 * read is refused the same way with or without a key.
 */
export function rejectReads(req, res, next) {
  if (req.method === 'GET' || req.method === 'HEAD') {
    res.set('Allow', 'POST, PUT, PATCH');
    return res.status(405).json({
      error: 'MethodNotAllowed',
      message: 'Client endpoints are write-only. Read data through /export with the export key.',
    });
  }
  next();
}

/**
 * Validates x-api-key exclusively against EXPORT_API_KEY.
 * Rejects write keys and missing keys.
 */
export function exportApiKeyAuth(req, res, next) {
  const apiKey = req.header('x-api-key');

  if (!apiKey) {
    return res.status(401).json({
      error: 'Unauthorized',
      message: 'Missing x-api-key header for export.',
    });
  }

  // Strictly enforce that export endpoints only accept the dedicated EXPORT_API_KEY
  if (apiKey !== config.exportApiKey) {
    return res.status(403).json({
      error: 'Forbidden',
      message: 'Invalid export API key. Write keys cannot access export endpoints.',
    });
  }

  req.auth = {
    type: 'apiKey',
    key: apiKey,
    role: 'export_read_only',
  };

  next();
}
