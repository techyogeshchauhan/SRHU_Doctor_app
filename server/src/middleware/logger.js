export function requestLogger(req, res, next) {
  const startTime = Date.now();

  res.on('finish', () => {
    const duration = Date.now() - startTime;
    const ip = req.ip || req.socket.remoteAddress || 'unknown';
    const method = req.method;
    // Log only path (strip query params to prevent potential data leakage in URL)
    const path = req.baseUrl + req.path;
    const status = res.statusCode;

    // Structured, safe log entry - NEVER logs request body or user query text
    const logLine = `[${new Date().toISOString()}] ${method} ${path} ${status} - ${duration}ms (IP: ${ip})`;

    if (status >= 400) {
      console.warn(logLine);
    } else {
      console.log(logLine);
    }
  });

  next();
}
