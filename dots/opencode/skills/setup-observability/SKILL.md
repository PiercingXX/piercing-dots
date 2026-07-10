---
name: setup-observability
description: Setup monitoring, logging, alerting, tracing. Observability foundation. Know what's happening in production in real-time.
compatibility: host-agnostic
metadata:
  source: legacy-flat-markdown
---


# Setup Observability (Monitoring & Logging)

You are a DevOps/SRE engineer. Your job is to give the team visibility into production.

## Activation Contract

Use this skill when the user needs monitoring, logging, tracing, alerting, or measurable runtime visibility.

Start by identifying the actual system surface first:
- running application or service
- deploy target or hosting layer
- existing metrics/logging stack
- repo type: app repo vs docs/config/setup repo

If the repo is primarily docs/config/setup, focus on observability planning, release signals, and runtime handoff requirements instead of inventing app instrumentation.

Treat all code and command blocks in this skill as implementation patterns to adapt to the current stack, not default instructions to apply blindly.

## When to use

- New production deployment (need to know what's happening)
- Incident occurred (need data to debug)
- Performance degradation (need metrics to diagnose)
- Adding monitoring to existing system

## Inventory First

Before implementation, answer:

1. What runtime actually exists?
2. What signals already exist?
3. Which critical user journeys need visibility?
4. Which alerts are actionable rather than noisy?

## Three Pillars

### 1. Metrics (Numbers)

What: CPU, memory, requests/sec, errors, latency

```bash
# Example metrics to track:
- Server CPU: Should be < 70% under normal load
- Server Memory: Should be < 80%, watch for leaks
- Request count: Track per endpoint, should be stable
- Error rate: Should be < 0.1%, alert if > 0.5%
- Latency: Track p50, p95, p99
  - p50: 50ms (normal)
  - p95: 150ms (acceptable)
  - p99: 500ms (concerning, might indicate spike)
```

Set up with Prometheus or a comparable metrics backend if the current stack supports it:

```yaml
# prometheus.yml
global:
  scrape_interval: 15s  # Collect every 15 seconds

scrape_configs:
  - job_name: 'myapp'
    static_configs:
      - targets: ['prometheus.example.invalid:9090']  # Your app's metrics endpoint
```

### 2. Logs (Stories)

What: What happened? When? Why?

```bash
# Structure logs so they're searchable
{
  "timestamp": "2024-01-15T14:30:45Z",
  "level": "INFO",
  "service": "api",
  "request_id": "req_12345",
  "message": "User login successful",
  "user_id": "usr_789",
  "latency_ms": 45
}
```

**Log levels:**
- `DEBUG`: Development only. Verbose details.
- `INFO`: Important events (login, request start)
- `WARN`: Something unexpected but recoverable (slow query, high memory)
- `ERROR`: Something broke but we caught it (DB connection failed, we retried)
- `FATAL`: Something broke and we're shutting down (we can't recover)

**What to log:**
```javascript
// ✓ Good
logger.info({ userId: 123, action: 'login' })

// ✗ Avoid
logger.info('User logged in')  // Not searchable
logger.debug(user)  // Logs entire object, includes password if you're not careful
```

### 3. Traces (Journeys)

What: How does a request flow through the system?

```bash
# Example: "User clicks login" trace
api.handler() → db.query(user) → crypto.verify(password) → jwt.sign()
#    10ms         5ms                 20ms                  2ms
# Total: 37ms

# If something is slow, you can see exactly where time was spent
```

Set up with tools like Jaeger or similar:

```javascript
// Instrument your code
const span = tracer.startSpan('db.query');
const result = await db.query('SELECT * FROM users');
span.end();
```

## Setup Steps

### Step 1: Metrics

```bash
# Choose the client library and integration pattern that match the repo's language/runtime.
# Example only (Node/Express):
const prometheus = require('prom-client');

// Create metrics
const httpRequestDuration = new prometheus.Histogram({
  name: 'http_request_duration_ms',
  help: 'Duration of HTTP requests in ms',
  labelNames: ['method', 'route', 'status_code']
});

const httpRequestTotal = new prometheus.Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'route', 'status_code']
});

// Track every request
app.use((req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    httpRequestDuration
      .labels(req.method, req.route, res.statusCode)
      .observe(duration);
    
    httpRequestTotal
      .labels(req.method, req.route, res.statusCode)
      .inc();
  });
  
  next();
});

// Expose metrics endpoint
app.get('/metrics', (req, res) => {
  res.set('Content-Type', prometheus.register.contentType);
  res.end(prometheus.register.metrics());
});
```

### Step 2: Logging

```bash
# Choose the logging library or built-in logging surface that matches the repo.
# Example only (Node):
const winston = require('winston');

const logger = winston.createLogger({
  format: winston.format.json(),
  transports: [
    // Console (development)
    new winston.transports.Console(),
    
    // File (everything)
    new winston.transports.File({
      filename: '/var/log/myapp.log',
      maxsize: 5242880,  // 5MB
      maxFiles: 5
    }),
    
    // Errors to separate file
    new winston.transports.File({
      level: 'error',
      filename: '/var/log/myapp-error.log'
    })
  ]
});

// Use it
logger.info('Application started', { version: '1.0.0' });
logger.error('Database connection failed', { 
  error: err.message,
  host: process.env.DB_HOST 
});
```

### Step 3: Alerts

Configure alerts to notify you of problems:

```yaml
# Alertmanager rules
groups:
  - name: myapp
    rules:
      # Alert if error rate > 0.5%
      - alert: HighErrorRate
        expr: |
          rate(http_requests_total{status_code=~"5.."}[5m]) > 0.005
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value }}"

      # Alert if latency p95 > 500ms
      - alert: HighLatency
        expr: |
          histogram_quantile(0.95, rate(http_request_duration_ms_bucket[5m])) > 500
        annotations:
          summary: "High latency detected"
          description: "P95 latency is {{ $value }}ms"

      # Alert if memory usage > 80%
      - alert: HighMemory
        expr: |
          process_resident_memory_bytes / 1024 / 1024 / 1024 > 0.8
        annotations:
          summary: "High memory usage"
          description: "Memory is {{ $value }}GB"
```

### Step 4: Tracing (Optional but Recommended)

```bash
# Choose the tracing SDK that matches the repo/runtime.
# Example only (Node/OpenTelemetry):
const { NodeSDK } = require('@opentelemetry/sdk-node');

const sdk = new NodeSDK({
  traceExporter: new JaegerExporter({
    endpoint: '<trace-endpoint>'
  })
});

sdk.start();
```

## Dashboards

Create a dashboard to see everything at a glance:

```
┌─ Application ─────────────────────────────────────┐
│ Requests/sec: 125      Error rate: 0.03%          │
│ P95 latency: 145ms     P99 latency: 250ms         │
└───────────────────────────────────────────────────┘

┌─ System Resources ────────────────────────────────┐
│ CPU:    ▓▓▓▓░░░░░░ 45%                            │
│ Memory: ▓▓▓▓▓▓░░░░ 62%                            │
│ Disk:   ▓▓▓▓░░░░░░ 48%                            │

## Degradation Policy

If the ideal observability stack cannot be implemented, degrade explicitly:

- no metrics endpoint -> use health checks and structured logs first
- no tracing backend -> add correlation IDs and latency logs
- no alert manager -> document manual thresholds and escalation rules
- no running service yet -> produce an observability readiness plan, not fake instrumentation completion

## Verification States

- `PASS`: critical signals, owners, and alert paths are defined and verifiable
- `FAIL`: key failure modes remain unobservable
- `AMBIGUOUS`: partial instrumentation exists, but critical journeys or alert paths are still missing
└───────────────────────────────────────────────────┘

┌─ Top Error Endpoints ─────────────────────────────┐
│ /api/upload: 15 errors                             │
│ /api/search: 8 errors                              │
│ /api/payment: 3 errors                             │
└───────────────────────────────────────────────────┘

┌─ Latency Distribution ────────────────────────────┐
│ < 50ms:   ███████████░░░░░░░░ (65%)               │
│ 50-100ms: ████░░░░░░░░░░░░░░░ (20%)               │
│ 100-500ms:███░░░░░░░░░░░░░░░░ (12%)               │
│ > 500ms:  █░░░░░░░░░░░░░░░░░░ (3%)                │
└───────────────────────────────────────────────────┘
```

## On-Call Runbook

When something breaks, you need a playbook:

```markdown
# On-Call Runbook

## High Error Rate (> 1%)

**Step 1: Identify the problem**
```bash
# Check which endpoint is failing
curl -s https://prometheus.example.invalid/api/v1/query \
  'rate(http_requests_total{status_code=~"5.."}[1m])'

# See recent error logs
tail -100 /var/log/myapp-error.log | grep ERROR

# Check if there's a pattern
grep "database connection" /var/log/myapp-error.log | wc -l
```

**Step 2: Decide: Mitigation or Fix?**
- If database down → Scale back traffic (feature flag for non-critical features)
- If code bug → Rollback or deploy fix (whichever is faster)
- If external API down → Show users a message, queue for retry later

**Step 3: Notify stakeholders**
"We're experiencing [issue]. ETA to restore: [time]. Will update every 10 min."

## Latency Spike (P95 > 300ms)

**Check:**
```bash
# Is it a specific endpoint?
curl -s https://prometheus.example.invalid/api/v1/query \
  'histogram_quantile(0.95, rate(http_request_duration_ms_bucket[1m])) by (route)'

# Database slow?
psql -U postgres -d mydb -c 'SELECT * FROM pg_stat_statements ORDER BY total_time DESC LIMIT 5;'

# Memory leak?
ps aux | grep node  # Check memory growth over time
```

**Fix options:**
- Add database index
- Scale horizontally (add more servers)
- Enable caching
- Optimize slow query
```

## Key Metrics by Service Type

### REST API
```
- Request count (per endpoint)
- Response time (p50, p95, p99)
- Error rate (by status code)
- Request size (huge payloads = slow)
- Response size (huge responses = slow)
```

### Background Jobs
```
- Job count (queued, processing, completed, failed)
- Job duration (how long do they take?)
- Job failure rate (are they crashing?)
- Queue depth (are we falling behind?)
```

### Database
```
- Query count (per query, per user)
- Query time (slow queries)
- Connections (used vs max)
- Replication lag (if replicated)
```

### Frontend
```
- Page load time
- Time to interactive
- JavaScript errors
- API response time (perceived by user)
- User sessions (active, returning, new)
```

## Output

```markdown
# Observability Setup

## Metrics
- [✓] Prometheus installed
- [✓] Custom metrics added (requests, latency, errors)
- [✓] /metrics endpoint exposed
- [✓] Prometheus scrape config updated

## Logging
- [✓] Winston configured
- [✓] JSON structured logging
- [✓] Separate error log file
- [✓] Log level configured (INFO in prod, DEBUG in dev)

## Alerts
- [✓] Error rate alert (> 0.5%)
- [✓] Latency alert (p95 > 200ms)
- [✓] Memory alert (> 80%)
- [✓] Alertmanager configured

## Dashboard
- [✓] Grafana or similar dashboard created
- [✓] Key metrics visible
- [✓] Alerts visible

## On-Call
- [✓] Runbook written and tested
- [✓] Team knows how to access metrics
- [✓] Escalation policy clear
```

## Key Rules

1. **You can't improve what you don't measure** — Instrument everything
2. **Alert on symptoms, not metrics** — Alert on error rate, not CPU (might be normal)
3. **Dashboards are for humans** — Chart what a human needs to know in < 30 seconds
4. **Logs are for machines** — Structure them so you can search and filter

## Principle

Good observability means you sleep at night.
