# Quality Checklist

## P0 — Must pass before emitting

- [ ] Design system tokens mapped to CSS `:root` custom properties
- [ ] Template HTML read and used as structural starting point
- [ ] No invented brand colors — all from DESIGN.md
- [ ] All placeholder metrics labelled with `—` (en-dash), never fabricated numbers
- [ ] HTML is self-contained (inline CSS + JS, no external dependencies)
- [ ] No forbidden anti-patterns present (see design-prototype SKILL.md)

## P1 — Must pass before declaring complete

- [ ] Self-critique score ≥ 3/5 across all 5 dimensions
- [ ] Visual hierarchy readable in 3 seconds
- [ ] Consistent spacing/weight/color throughout
- [ ] Mobile-responsive if web surface
- [ ] Font families match DESIGN.md typography spec

## P2 — Nice to have

- [ ] Dark mode variant provided
- [ ] Interaction states (hover, focus, active) defined
- [ ] Animation/transition present if motion would add value
- [ ] Accessibility: sufficient contrast, semantic HTML, ARIA labels where needed
