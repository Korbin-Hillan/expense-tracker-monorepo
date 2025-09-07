import { Request, Response, NextFunction } from "express";

interface RateLimitOptions {
  windowMs: number;
  maxRequests: number;
  message?: string;
  skipSuccessfulRequests?: boolean;
  skipFailedRequests?: boolean;
}

interface ClientInfo {
  count: number;
  resetTime: number;
}

export function createRateLimit(options: RateLimitOptions) {
  const {
    windowMs,
    maxRequests,
    message = "Too many requests, please try again later.",
    skipSuccessfulRequests = false,
    skipFailedRequests = false,
  } = options;

  const clients = new Map<string, ClientInfo>();

  // Clean up expired entries every 10 minutes
  setInterval(() => {
    const now = Date.now();
    for (const [ip, info] of clients.entries()) {
      if (now > info.resetTime) {
        clients.delete(ip);
      }
    }
  }, 10 * 60 * 1000);

  return (req: Request, res: Response, next: NextFunction): void => {
    const clientId = req.ip || req.socket.remoteAddress || "unknown";
    const now = Date.now();
    
    let clientInfo = clients.get(clientId);
    
    if (!clientInfo || now > clientInfo.resetTime) {
      clientInfo = {
        count: 0,
        resetTime: now + windowMs,
      };
      clients.set(clientId, clientInfo);
    }

    // Check if request should be counted
    const shouldCount = () => {
      if (skipSuccessfulRequests && res.statusCode >= 200 && res.statusCode < 400) {
        return false;
      }
      if (skipFailedRequests && res.statusCode >= 400) {
        return false;
      }
      return true;
    };

    // If we've exceeded the limit
    if (clientInfo.count >= maxRequests) {
      res.status(429).json({
        error: "rate_limit_exceeded",
        message,
        retryAfter: Math.ceil((clientInfo.resetTime - now) / 1000),
      });
      return;
    }

    // Increment counter (will be updated after response if needed)
    const originalEnd = res.end;
    res.end = function(...args: any[]) {
      if (shouldCount()) {
        clientInfo!.count++;
      }
      res.end = originalEnd;
      return originalEnd.apply(res, args);
    };

    // Add headers
    res.set({
      'X-RateLimit-Limit': maxRequests.toString(),
      'X-RateLimit-Remaining': Math.max(0, maxRequests - clientInfo.count - 1).toString(),
      'X-RateLimit-Reset': Math.ceil(clientInfo.resetTime / 1000).toString(),
    });

    next();
  };
}

// Predefined rate limiters
export const strictRateLimit = createRateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  maxRequests: 100,
  message: "Too many requests from this IP, please try again after 15 minutes.",
});

export const authRateLimit = createRateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  maxRequests: 5,
  message: "Too many authentication attempts, please try again after 15 minutes.",
  skipSuccessfulRequests: true,
});

export const apiRateLimit = createRateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  maxRequests: 1000,
  message: "API rate limit exceeded, please try again later.",
});