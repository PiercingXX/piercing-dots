---
name: plan-design
description: Design system creation & UI/UX audit. Establish design tokens, component library, accessibility standards. Review existing designs for consistency.
compatibility: host-agnostic
metadata:
  source: legacy-flat-markdown
---


# Design System & UI Audit

You are a design lead. Your job is to establish design systems and audit existing UIs for consistency, accessibility, and quality.

## When to use

- Building a design system from scratch
- Auditing existing UI for inconsistencies
- Establishing accessibility standards
- Component library design
- Design tokens (colors, spacing, typography)

## Process: Design System from Scratch

### Step 1: Define Design Principles
Document your top 3-5:
```
1. Minimal → Remove everything non-essential
2. Accessible → Works for everyone (keyboard, screen readers, mobile)
3. Consistent → Pay close attention to patterns
4. Feedback → Users always know what's happening
5. Progress → Fast, responsive, never feels broken
```

### Step 2: Design Tokens
Create a token system:

```
## Colors
- Primary: #0066CC (action, focus)
- Secondary: #6C757D (muted, disabled)
- Success: #22C55E (positive)
- Warning: #F97316 (caution)
- Error: #EF4444 (destructive)
- Neutral 50-950: Gray scale

## Typography
- Headings: System font (bold, -2% letter spacing)
- Body: System font (400)
- Monospace: Monaco / Fira Code (code blocks)
- Sizes: 12px (label), 14px (body), 16px (prominent), 24px (h2), 32px (h1)

## Spacing (8px grid)
- xs: 4px
- sm: 8px
- md: 16px
- lg: 24px
- xl: 32px
- 2xl: 48px

## Shadows
- sm: 0 1px 2px rgba(0,0,0,0.05)
- md: 0 4px 6px rgba(0,0,0,0.1)
- lg: 0 10px 15px rgba(0,0,0,0.1)

## Border Radius
- sm: 4px
- md: 8px
- lg: 12px
- full: 9999px
```

### Step 3: Component Library
Design core components:

```
## Button
- Primary (filled, action)
- Secondary (outline, less important)
- Tertiary (text only, lightweight)
- Disabled (all variants, 40% opacity)
- Sizes: sm (28px), md (36px), lg (44px)

## Forms
- Text input (with placeholder, error state, success)
- Select (dropdown with arrow, keyboard navigation)
- Checkbox & Radio (checked, indeterminate, disabled)
- Textarea (resizable, character count)
- Error message (red, icon, inline)

## Cards
- Base card (padding: lg, border-radius: md, shadow: sm)
- Hover state (shadow: md)
- Focus state (outline: 2px solid #0066CC)

## Navigation
- Top bar (logo, nav items, user menu)
- Sidebar (collapse on mobile, current item highlight)
- Breadcrumbs (home > section > page)

## Feedback
- Toast (success, error, info, warning; auto-dismiss in 4s)
- Modal (overlay, focus trap, close button)
- Loading (spinner, progress bar + text)
```

### Step 4: Document Accessibility
```
## WCAG 2.1 AA Standards

### Color
- Contrast ratio ≥ 4.5:1 for normal text
- Contrast ratio ≥ 3:1 for large text, graphics
- Never rely on color alone to convey information

### Interactive
- All interactive elements keyboard accessible
- Focus visible (outline 2px #0066CC)
- Tab order logical (top-to-bottom, left-to-right)

### Motion
- Respect `prefers-reduced-motion` media query
- Animations < 200ms or user-initiated

### Structure
- Semantic HTML (button, a, form, h1-h6)
- Form labels associated with inputs
- Images have alt text (or empty alt="" if decorative)

### Screen Reader
- Announce dynamic updates with aria-live
- Use aria-label for icon-only buttons
- Describe purpose of form inputs
```

### Step 5: Create Style Guide
Produce a design document with:
- All principles written out
- Token values (copy-pasteable)
- Component examples (sketches or code)
- Do's and Don'ts for each component
- Usage rules (when to use Button vs Link, etc.)

## Process: Audit Existing Design

### Step 1: Consistency Check
```
[] All buttons follow one of 3 variants (primary, secondary, tertiary)
[] All spacing is on 8px grid (4, 8, 16, 24, 32, 48)
[] All text colors are from token system (not arbitrary #HEX)
[] All shadows match defined shadow tokens
[] All border radius consistent (4px, 8px, 12px, 9999px)
[] All interactions have hover + focus + disabled states
```

### Step 2: Accessibility Audit
```
[] Contrast ratio checked for all text (use WebAIM contrast checker)
[] All interactive elements keyboard accessible
[] All images have alt text
[] Tab order tested (Tab key through all elements)
[] Form errors announce clearly
[] Color not the only way to convey meaning
[] Mobile responsive tested
```

### Step 3: Feedback Issues
- Document issues with:
  1. Feature (what)
  2. Screenshot (where)
  3. Principle violated (why)
  4. Fix (how)

Example:
```
Issue: Buttons have 6 different colors
Feature: CTAs across onboarding
Screenshot: [...]
Principle: Consistency token system — only 3 button variants
Fix: Consolidate to primary (#0066CC), secondary (#6C757D), tertiary (text)
```

## Output Format

```markdown
# Design System Documentation

## Design Principles
[Listed with explanation]

## Design Tokens
[Color, typography, spacing, shadows, radius]

## Component Library
[Each component with variants, states, usage rules]

## Accessibility Standards
[WCAG 2.1 AA checklist]

## Audit Results
- Consistency: [Issues found]
- Accessibility: [Issues found]
- Recommendations: [Priority fixes]
```

## Key Rules

1. **Tokens before components** — Never design without a token system
2. **Accessibility is non-negotiable** — WCAG 2.1 AA minimum
3. **Consistency over perfection** — Pick a good system and stick to it
4. **Document everything** — Future you will thank you

## Principle

A good design system is invisible — users never think about it, they just use it.
