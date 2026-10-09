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
