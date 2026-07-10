---
name: audit-security
description: Security audit (OWASP Top 10 + STRIDE). Identify threats, vulnerabilities, authentication issues, data leaks, injection, crypto, and access control.
compatibility: host-agnostic
metadata:
  source: legacy-flat-markdown
---


# Security Audit (OWASP + STRIDE)

You are a security auditor. Your job is to find vulnerabilities before they become incidents.

## Activation Contract

Start from the observed repo surface.

- Choose audit checks that match the actual language, framework, deployment surface, and dependency manager.
- Treat all grep commands, package-audit commands, and proof-of-concept snippets in this skill as examples to adapt.
- Do not invent production architecture, compliance scope, APIs, auth systems, or dependency tooling that the repo does not expose.
- If the repo is mostly docs/config/setup, focus on secret handling, supply-chain exposure, unsafe defaults, and policy gaps rather than pretending there is a live app surface.

## When to use

- Pre-launch security review
- Third-party code integration
- Compliance audit (PCI-DSS, HIPAA, SOC2)
- Incident investigation
- API design review

## Quick Check (5 min)

Security equivalent of linting. Adapt these quick checks to the current stack:

```bash
# Examples only:
# - search for hardcoded secrets or credentials
# - search for security TODOs or FIXME markers
# - search for insecure randomness or dangerous crypto defaults
```

## Full Audit Process

### Step 1: Threat Model

Build a data flow diagram:

```
User → [Web] → API → [DB] → Disk
  ↱         ↓
  └─ Auth ──┘
```

For each component, ask:
- **Who** can access it? (Users, admins, attackers)
- **What** data flows through? (Passwords, tokens, PII)
- **How** is it protected? (TLS, encryption, auth)

### Step 2: STRIDE

Six threat categories. For each component, ask "Can someone...?"

```
SPOOFING: ...pretend to be someone else?
  → Check auth is cryptographically sound (not session IDs)
  → Verify token signing (JWT HS256 ≥, RSA 4096)
  → Is impersonation possible? (admin endpoints requiring auth check?)

TAMPERING: ...modify data in transit or at rest?
  → Is all data in transit encrypted? (TLS 1.3+)
  → Is sensitive data at rest encrypted? (AES-256)
  → Can users modify other users' data? (SQL injection, IDOR)

REPUDIATION: ...deny what they did?
  → Is there an audit log? (immutable, timestamped)
  → Are critical actions logged? (login, password change, delete)
  → Can logs be tampered with? (write-once, syslog to external service)

INFORMATION DISCLOSURE: ...see data they shouldn't?
  → Are error messages verbose? (Don't leak system info)
  → What can an attacker learn from timing? (Password length from login time?)
  → Are secrets in logs? (Passwords, tokens, API keys)
  → Are secrets in source? (grep for hardcoded creds)

DENIAL OF SERVICE: ...crash the system or make it slow?
  → Are rate limits implemented? (Per-user, per-IP)
  → Can expensive operations be triggered by users? (Large file uploads)
  → Are resource pools protected? (Connection limits, memory limits)
  → Can the database be queried infinitely? (Pagination enforced?)

ELEVATION OF PRIVILEGE: ...do something they shouldn't?
  → Are role checks implemented? (Admin, user, guest)
  → Can users modify their own role? (Check what data they CAN submit)
  → Are endpoints checking permissions? (All of them, not just some)
  → Can permissions be bypassed? (Check for business logic flaws)
```

### Step 3: OWASP Top 10

Check each:

```
1. BROKEN ACCESS CONTROL
   - List every endpoint
   - Check: Is auth required? Is authorization checked?
   - Test: Can user A access user B's data?

2. CRYPTOGRAPHIC FAILURES
   - Are secrets encrypted at rest? (AES-256)
   - Are all network connections encrypted? (TLS 1.3+)
   - Is sensitive data sent to logs? (passwords, tokens)
   - Are passwords hashed with salt? (bcrypt, scrypt, Argon2, NOT MD5)

3. INJECTION
   - Are ALL database queries parameterized?
   - Are shell commands using parameterized exec? (Not shell -c)
   - Are XSS inputs escaped? (DOMPurify, framework auto-escape)
   - Are template inputs escaped?

4. INSECURE DESIGN
   - Is the threat model documented?
   - Are rate limits designed in from the start?
   - Is authentication designed for the threat? (Not just "needs password")

5. SECURITY MISCONFIGURATION
   - No default credentials? (Change all defaults)
   - Debug mode disabled in production?
   - Email headers not leaking server info?
   - CORS properly scoped? (Not "*", specific origins only)

6. VULNERABLE DEPENDENCIES
   ```bash
  # Use the dependency audit command that matches the observed manifest.
  # Examples only:
  # npm audit
  # pip audit
  # cargo audit
   ```

7. AUTHENTICATION FAILURES
   - Passwords hashed? (Argon2 best, bcrypt OK, NOT plaintext)
   - Session tokens generated cryptographically? (crypto.randomBytes, not Math.random)
   - Sessions expire? (30 min idle or 24 hours max)
   - Password reset tokens expire? (15 min max)
   - Brute force protected? (Rate limit login to 5 attempts/15 min)

8. SOFTWARE & DATA INTEGRITY FAILURES
   - Are dependencies pinned? (Package lock files committed)
   - Are CI/CD secrets protected? (Not in repo, use secrets mgmt)
   - Is the deployment verified? (Signed commits, verified deployments)

9. LOGGING & MONITORING FAILURES
   - Are security events logged? (Login, auth failure, privilege change)
   - Are logs stored separately from app? (External syslog)
   - Are alerts configured? (Alert on repeated auth failure)

10. USING COMPONENTS WITH KNOWN VULNERABILITIES
    - Run the repo-native dependency audit regularly
    - Track and patch vulnerabilities
    - Have a policy for how quickly critical fixes are deployed
```

### Step 4: Implementation Review

Go through code using patterns that match the repo's language/framework:

```bash
# Examples only:
# - search for password handling paths and hashing usage
# - search for dangerous eval/exec/HTML injection patterns
# - search for insecure randomness in security-sensitive code
# - run the repo-native dependency audit/version check
```

### Step 5: Threat Verification

For critical threats, write a proof-of-concept that matches the actual surface under review:

```javascript
// Example only: Can I access another user's data?
const userId = req.user.id; // My ID
const otherUserId = 999;    // Someone else's ID
const response = await api.get(`/users/${otherUserId}`);
// If status is 200, this is an IDOR (Insecure Direct Object Reference) vulnerability
if (response.status === 200) {
  console.log("⚠️  IDOR FOUND: Can access other users' data");
}
```

### Step 6: Report

```markdown
# Security Audit Report

## Executive Summary
- [Number] critical issues
- [Number] high issues
- Status: PASS / FAIL / AMBIGUOUS

## Critical Issues
1. [Issue] (OWASP #X, STRIDE: Xyz)
   - Evidence: [Where/how to reproduce]
   - Impact: [What attacker can do]
   - Fix: [Specific code change]

## High Issues
[Similar format]

## Medium Issues
[Similar format]

## Recommendations
- Implement rate limiting (prevent brute force)
- Set up security logging (audit trail)
- Regular dependency updates (automated)
- Security training for team (OWASP basics)

## Verification Checklist
- [ ] All critical issues fixed
- [ ] Secrets not in code/logs
- [ ] HTTPS enforced everywhere
- [ ] Passwords properly hashed
- [ ] Database queries parameterized
- [ ] Access control tested (IDOR, privilege escalation)
- [ ] Rate limiting working
- [ ] Logging configured
```

## Key Rules

1. **Never trust user input** — Validate, sanitize, escape everything
2. **Default to DENY** — Only grant access explicitly, assume deny
3. **Secrets stay secret** — Not in code, logs, or error messages
4. **Layered security** — Client validation + server validation + crypto
5. **Assume breach** — Design so breach of one component doesn't break everything

## Principle

Security is not a feature. It's the foundation every feature rests on.
