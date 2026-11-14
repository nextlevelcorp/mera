<!--
Summary written for Mera from https://github.com/EveryInc/compound-engineering-plugin
(README "Philosophy" and "The loop", CONCEPTS.md, skill descriptions of ce-brainstorm, ce-plan,
ce-work, ce-simplify-code, ce-code-review, ce-compound, ce-debug, ce-test-browser) at commit ee46dde,
fetched 2026-11-14. Copyright (c) 2025 Every, MIT License. Paraphrased, not copied.
See THIRD_PARTY_NOTICES.md in this folder.
-->

# Compound engineering (core workflow)

Read for: any non-trivial feature, a bug whose cause is unknown, and before every review.

## Principle

Each unit of work should make the next one easier. Most of the effort goes into planning and review;
execution is the smaller part. What a task teaches is written down where the next task will find it.

## The loop

1. **Brainstorm** the requirement until it is a short, testable statement. For Mera this is the
   scope block CLAUDE.md asks for: in, out, done-when.
2. **Plan** the implementation: files touched, data and schema changes, tests that prove each
   clause, risks. One plan grows from requirements into implementation steps; it is not rewritten.
3. **Work** through the plan in small, playable increments. Run the tests after each step.
4. **Simplify** what was just written: remove dead branches, single-use abstractions, comments that
   restate code, tests that assert nothing.
5. **Review** the diff against the plan before merging: bugs, regressions, missing tests, pillar
   and rule violations (sources, localisation, determinism, debug gating, no secrets).
6. **Compound**: when verified work corrected a wrong belief (a failed approach, a defect the review
   caught, a wrong assumption in a doc), capture it in its cheapest durable form, in this order of
   preference: a test or a lint rule, a coding rule in `.claude/rules/`, a line in the relevant doc.
   Do not write a learning for work that went exactly as planned.

## Debugging

Reproduce first, then form one hypothesis at a time, change one thing, re-run the same check.
A regression test is trusted only after it has been seen failing against the unfixed code.

## Browser checks

After a change that affects what the player sees, open the affected screen in the browser, capture
console errors and screenshots, and exercise the input that changed (see `game-studios.md`).

## Mera mapping

| Loop step | Where it lives in Mera |
| --- | --- |
| Brainstorm, plan | Scope block in the reply; larger plans in `docs/` |
| Work | Feature branch, draft PR |
| Review | `code-review` plugin or skill on the diff before the PR is marked ready |
| Compound | Tests in `game/tests/`, rules in `.claude/rules/`, notes in `docs/` |
