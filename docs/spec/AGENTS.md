# Authoring the Spec

The spec is terse reference material about a problem, written for people who know Nix well and have not felt this particular pain.

## Scope

- The spec says what is being solved, never how.
- A different implementation that meets the goals should require no change to the spec.
- Problems, goals, and constraints belong here. Mechanisms, interfaces, and the names of anything rhizome defines do not.
- Use the nouns in [README](README.md). They describe the problem and are deliberately not the library's vocabulary.
- Nothing here depends on one person's configuration, workflow, or measurements.
- The spec never describes or refers to existing code.
- Something learned from a failed attempt is recorded as the constraint it revealed, not as the attempt.
- Say only what is decided. If something is undecided, leave it out.

## Shape

- One page per topic. A new page is added to the list in `README.md` with a one-line summary.
- A page opens with a sentence or two. Everything after is sections of bullets.
- A bullet is one or two sentences. No tables or code.
- A fact lives on one page. Other pages link to it.
- State a rule, then its consequence, as separate bullets. Give a reason only where the rule would otherwise look arbitrary.
- Leave out what an expert would infer.
- A reader should be able to disagree with a sentence, never wonder what it meant.

## Changing it

- Reversing a decision means editing the bullet that states it and every bullet that follows from it. Never append a correction.
- A change to a goal or constraint comes before the code that relies on it.
