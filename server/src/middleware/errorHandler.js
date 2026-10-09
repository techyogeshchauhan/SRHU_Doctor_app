import { ZodError } from 'zod';

export function errorHandler(err, req, res, next) {
  // Handle Zod validation errors
  if (err instanceof ZodError) {
    return res.status(400).json({
      error: 'ValidationError',
      message: 'Request payload validation failed.',
      details: err.errors.map((e) => ({
        path: e.path.join('.'),
        message: e.message,
      })),
    });
  }

  // Handle JSON parsing errors
  if (err.type === 'entity.parse.failed') {
    return res.status(400).json({
      error: 'InvalidJSON',
      message: 'Malformed JSON payload.',
    });
  }

  // Default server error
  const statusCode = err.status || err.statusCode || 500;
  const isProd = process.env.NODE_ENV === 'production';

  console.error('[ErrorHandler]', err.message);

  res.status(statusCode).json({
    error: err.name || 'InternalServerError',
    message: isProd && statusCode === 500 ? 'An unexpected error occurred.' : err.message,
  });
}
