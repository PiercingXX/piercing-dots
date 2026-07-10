---
name: write-docs
description: Generate project documentation. API docs, README, installation guide, deployment guide, changelog. Clear, discoverable, user-friendly.
compatibility: host-agnostic
metadata:
  source: legacy-flat-markdown
---


# Write Documentation

You are a technical writer. Your job is to explain your software clearly so users and developers can succeed.

## Activation Contract

Start from the observed repo surface.

- Infer the actual install, run, deploy, and troubleshooting flows from files that exist in the repo.
- Treat all command blocks in this skill as templates to adapt, not copy-paste defaults.
- Do not invent Node, Python, Docker, Kubernetes, databases, ports, or cloud services unless the repo surface proves they exist.
- If the repo is docs/config/setup-oriented, document artifact flow and validation instead of pretending there is an application runtime.

## When to use

- Shipping new feature (needs user guide)
- New open-source project (needs README + guides)
- API change (needs API docs update)
- Releasing version (needs changelog)
- Setting up complex system (needs deployment guide)

## README (Landing Page)

Your README is the first thing people read. It should answer:
1. "What is this?" (1 sentence)
2. "Why should I care?" (2-3 sentences)
3. "How do I get started?" (5 min quick start)
4. "Where do I learn more?" (Links to docs)

### Structure

```markdown
# Project Name

> One-sentence description. What does it do?

## Features

- Feature 1: Benefit to user
- Feature 2: Benefit to user
- Feature 3: Benefit to user

## Quick Start

### Install
\`\`\`bash
# Use the real install command for this repo/package.
# Examples only:
# npm install package-name
# pip install package-name
\`\`\`

### Usage
\`\`\`javascript
import { thing } from 'package-name';

thing.doSomething();  // Output: Result
\`\`\`

## Documentation

- [Installation Guide](./docs/install.md) — Detailed setup
- [API Reference](./docs/api.md) — All functions/classes
- [Examples](./docs/examples/) — Real-world usage
- [Troubleshooting](./docs/troubleshooting.md) — Common issues

## Contributing

We welcome contributions. See [CONTRIBUTING.md](./CONTRIBUTING.md).

## License

MIT (or your license)
```

## Installation Guide

For anything beyond a trivial single-command install, derive the setup flow from the repo first.

Look at files such as `package.json`, `Makefile`, `pyproject.toml`, `Cargo.toml`, Docker files, CI config, compose files, infra manifests, and existing docs.

The structure below is a template to adapt to the actual project:

```markdown
# Installation Guide

## Supported Platforms
- Linux (Ubuntu 20.04+)
- macOS 11+
- Windows 10+ (with WSL2)

## Prerequisites
- Node 18+
- PostgreSQL 12+
- Redis 6+

## Steps

### 1. Clone Repository
\`\`\`bash
git clone https://example.com/team/project.git
cd project
\`\`\`

### 2. Install Dependencies
\`\`\`bash
# Use the repo-native dependency install step.
# Examples only:
# npm install
# bun install
# pip install -r requirements.txt
# cargo build
\`\`\`

### 3. Configure Environment
\`\`\`bash
cp .env.example .env
# Edit .env with your settings:
# - DATABASE_URL=postgresql://...
# - REDIS_URL=redis://...
\`\`\`

### 4. Setup Database
\`\`\`bash
# Only include this section if the repo actually has a database.
# Examples only:
# npm run db:migrate
# npm run db:seed
\`\`\`

### 5. Start Development Server
\`\`\`bash
# Use the real local run command and URL for this repo.
# Examples only:
# npm run dev
# bun dev
# python -m app
\`\`\`

## Troubleshooting

### "Connection refused" error
- Check PostgreSQL is running: `pg_isready`
- Verify DATABASE_URL in .env is correct

### Port already in use
\`\`\`bash
# Use the actual override supported by the repo.
\`\`\`

See [Troubleshooting](./troubleshooting.md) for more.
```

## API Documentation

Organize by resource:

```markdown
# API Reference

## Authentication

All requests require Bearer token in Authorization header.

\`\`\`bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
  https://api.example.com/users/me
\`\`\`

## Users

### Get Current User
\`\`\`http
GET /users/me
Authorization: Bearer YOUR_TOKEN

Response (200):
{
  "id": "usr_123",
  "email": "user@example.com",
  "name": "John Doe"
}
\`\`\`

### List Users (Admin Only)
\`\`\`http
GET /users
Authorization: Bearer YOUR_TOKEN (admin)

Query Parameters:
- page: [1-∞] (default: 1)
- limit: [1-100] (default: 20)
- sort: [name|created] (default: name)

Response (200):
{
  "data": [...],
  "page": 1,
  "limit": 20,
  "total": 150
}
\`\`\`

### Create User (Admin Only)
\`\`\`http
POST /users
Authorization: Bearer YOUR_TOKEN (admin)
Content-Type: application/json

Request Body:
{
  "email": "newuser@example.com",
  "name": "Jane",
  "role": "user"
}

Response (201):
{
  "id": "usr_456",
  "email": "newuser@example.com",
  "name": "Jane",
  "role": "user"
}

Errors:
- 400: Email already exists
- 403: Not an admin
\`\`\`

## Error Responses

All errors follow this format:

\`\`\`json
{
  "error": "error_code",
  "message": "Human-readable message"
}
\`\`\`

Common errors:
- `auth_required`: Missing/invalid token (401)
- `permission_denied`: Insufficient permissions (403)
- `not_found`: Resource doesn't exist (404)
- `validation_error`: Invalid input (400)
```

## Deployment Guide

For deployment documentation, describe only the release path that the current repo actually supports.

Use the structure below as a template, not a default stack choice.

```markdown
# Deployment Guide

## Pre-Deployment

### Checklist
- [ ] All deterministic validation checks passing (use repo-native command)
- [ ] No console errors
- [ ] Build or artifact generation succeeds (use repo-native command)
- [ ] Staging deployed and verified
- [ ] Database migrations prepared
- [ ] Environment variables set

### Environment Variables

\`\`\`bash
# Show only the environment variables the repo actually requires.
# Use placeholders, never real secrets.
\`\`\`

## Deploy to Production

### Option 1: Container or Image-Based Deploy

\`\`\`bash
# Examples only. Replace with the actual image build/publish/deploy flow if present.
\`\`\`

### Option 2: Direct Host or VM Deploy

\`\`\`bash
# Examples only. Replace with the actual host-based release flow if present.
\`\`\`

## Verify Deployment

\`\`\`bash
# Use the actual verification checks exposed by this repo or deployment surface.
\`\`\`

## Rollback

If something goes wrong:

\`\`\`bash
# Document the real rollback path only if it exists.
\`\`\`
```

## Changelog

Format changes for humans:

```markdown
# Changelog

All notable changes to this project will be documented in this file.

## [1.2.0] - 2024-01-15

### Added
- New `/export` endpoint for downloading data as CSV
- Dark mode theme support (Settings > Appearance)
- API authentication via Bearer tokens (more secure than API keys)

### Changed
- Updated data or config schema (include the actual migration or update step only if one exists)
- Improved error messages (now shows what field failed validation)
- Default page size increased from 10 to 20 items

### Fixed
- Login failing for users with special characters in passwords (Security fix)
- Race condition in concurrent file uploads
- Mobile layout broken on screens < 320px

### Removed
- Legacy `/api/v1/` endpoints (use `/api/v2/` instead)

### Security
- Updated dependencies to patch XSS vulnerability
- Rate limiting added to login endpoint (5 attempts per 15 min)

## [1.1.0] - 2024-01-01

### Added
- Dark mode (experimental)
- API documentation ([actual docs URL or path])

### Fixed
- Performance regression in search
```

## FAQ/Troubleshooting

Common questions and answers:

```markdown
# FAQ & Troubleshooting

## General

### Q: Is this suitable for production?
A: Answer only from observed evidence: deployment docs, scaling limits, SLOs, and operational support. Do not claim production readiness without proof.

### Q: What are the system requirements?
A: List only the requirements proven by the current repo and its docs.

## Technical

### Q: How do I connect to a different database?
A: Answer only if the repo actually exposes database configuration.

### Q: How do I enable debugging?
A: Use the actual debug flags or logging controls the repo exposes.
\`\`\`bash
# Example only. Replace with the real debug command.
\`\`\`

### Q: How do I contribute?
A: See [CONTRIBUTING.md](./CONTRIBUTING.md)

## Errors

### Port already in use
Only include service-specific guidance if the repo actually depends on that service.
\`\`\`bash
# Replace with the real diagnosis and recovery step.
\`\`\`

### Dependency service connection refused
Only include service-specific troubleshooting if the repo actually depends on that service.
\`\`\`bash
# Replace with the real dependency recovery step.
\`\`\`
```

## Documentation Checklist

Before shipping:

```
README
- [ ] What is this? (1 sentence)
- [ ] Why care? (2-3 sentences)
- [ ] Quick start (5 min)
- [ ] Links to full docs

Installation
- [ ] Step-by-step guide
- [ ] All prerequisites listed
- [ ] Troubleshooting section

API Docs (if applicable)
- [ ] Every endpoint documented
- [ ] Example requests + responses
- [ ] Error codes explained
- [ ] Authentication explained

Deployment
- [ ] Pre-flight checklist
- [ ] Step-by-step deploy
- [ ] Verification steps
- [ ] Rollback procedure

Changelog
- [ ] What's new in this version
- [ ] What changed
- [ ] What's fixed
- [ ] Breaking changes called out
```

## Key Rules

1. **Write for humans** — Be clear, not clever
2. **Show examples** — Code samples > theoretical explanations
3. **Update when you ship** — Stale docs are worse than no docs
4. **Link liberally** — Help people navigate between pages
5. **Assume nothing** — What's obvious to you is not obvious to new users

## Principle

Great documentation is invisible — users get what they need and never think about it.
