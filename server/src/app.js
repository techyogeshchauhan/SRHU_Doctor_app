import cors from 'cors';
import express from 'express';
import rateLimit from 'express-rate-limit';
import helmet from 'helmet';

import { config } from './config.js';
import { apiKeyAuth } from './middleware/auth.js';
import { errorHandler } from './middleware/errorHandler.js';
import { requestLogger } from './middleware/logger.js';
import chatLogsRouter from './routes/chatLogs.js';
import exportRouter from './routes/export.js';
import healthRouter from './routes/health.js';
import screeningsRouter from './routes/screenings.js';
import sessionsRouter from './routes/sessions.js';

export function createApp() {
  const app = express();

  // Security headers
  app.use(helmet());

  // CORS configuration
  const corsOptions = {
    origin: (origin, callback) => {
      // Allow requests with no origin (like mobile apps, curl, postman)
      if (!origin) return callback(null, true);

      if (config.allowedOrigins.length === 0 || config.allowedOrigins.includes(origin)) {
        return callback(null, true);
      }
      return callback(new Error(`Origin ${origin} not allowed by CORS`));
    },
    credentials: true,
  };
  app.use(cors(corsOptions));

  // Rate Limiting (100 requests per minute per IP, or 500 in dev)
  const limiter = rateLimit({
    windowMs: 60 * 1000,
    max: 120,
    standardHeaders: true,
    legacyHeaders: false,
    message: { error: 'TooManyRequests', message: 'Rate limit exceeded. Please slow down.' },
  });
  app.use(limiter);

  // Body parser with 1MB limit
  app.use(express.json({ limit: '1mb' }));

  // PHI-safe request logging
  app.use(requestLogger);

  // Unauthenticated health endpoint
  app.use('/health', healthRouter);

  // Export endpoints (custom export auth)
  app.use('/export', exportRouter);

  // Client data endpoints (guarded by x-api-key)
  app.use('/sessions', apiKeyAuth, sessionsRouter);
  app.use('/screenings', apiKeyAuth, screeningsRouter);
  app.use('/chat-logs', apiKeyAuth, chatLogsRouter);

  // 404 handler
  app.use((req, res) => {
    res.status(404).json({ error: 'NotFound', message: `Route ${req.method} ${req.path} not found.` });
  });

  // Centralized error handler
  app.use(errorHandler);

  return app;
}
