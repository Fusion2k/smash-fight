# Domain Docs

This repository uses a single-context layout:

- GLOSSARY.md at the repository root defines domain vocabulary.
- docs/adr/ contains architectural decision records.

## Before exploring

Read the glossary and ADRs relevant to the work.

If these files do not exist, proceed silently. Do not flag their
absence or suggest creating them upfront. The domain-modeling
skill creates them when terms or decisions are resolved.

## Use the glossary's vocabulary

Use defined domain terms in issue titles, proposals, hypotheses,
and test names. Avoid synonyms the glossary explicitly rejects.

If a needed concept is missing, reconsider whether it belongs
to the domain; record real vocabulary gaps for domain-modeling.

## Flag ADR conflicts

Explicitly identify proposals that contradict an existing ADR.
Reference the ADR and explain why its decision should be reopened.
