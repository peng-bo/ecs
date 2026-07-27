# Domain Docs

## Before exploring, read these

- `CONTEXT.md` at the repository root.
- `CONTEXT-MAP.md`, if present, and each context relevant to the work.
- Relevant ADRs under `docs/adr/`.

If these files do not exist, proceed silently. Domain-modeling skills create them lazily
when terms or decisions are resolved.

## File structure

This repository uses a single-context layout:

/
├── CONTEXT.md
├── docs/adr/
└── source packages

## Use the glossary vocabulary

Use terms as defined in `CONTEXT.md` in issue titles, proposals, hypotheses, and tests.
Do not drift to synonyms the glossary explicitly avoids. Note genuine vocabulary gaps
for domain modeling.

## Flag ADR conflicts

Explicitly identify output that contradicts an existing ADR rather than silently
overriding the decision.
