import * as client from 'prom-client';
import type { Request, Response, NextFunction } from 'express';

let initialized = false;
const httpHistogram = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status'] as const,
  buckets: [0.05, 0.1, 0.2, 0.5, 1, 2, 5]
});

export function initMetrics() {
  if (initialized) return;
  initialized = true;
  client.collectDefaultMetrics();
}

export function httpMetricsMiddleware(req: Request, res: Response, next: NextFunction) {
  const start = process.hrtime.bigint();
  const method = req.method;
  const route = (req.route?.path as string) || req.path || 'unknown';
  res.on('finish', () => {
    const durationNs = Number(process.hrtime.bigint() - start);
    const durationSec = durationNs / 1e9;
    httpHistogram.labels(method, route, String(res.statusCode)).observe(durationSec);
  });
  next();
}

export async function metricsHandler(_req: Request, res: Response) {
  res.set('Content-Type', client.register.contentType);
  res.end(await client.register.metrics());
}
