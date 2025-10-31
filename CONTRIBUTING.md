# Contributing Guidelines

Thanks for helping to move this project forward. These guidelines describe the workflows we follow so we can collaborate smoothly.

## Ground Rules

- Be kind and inclusive. Read and follow the `CODE_OF_CONDUCT.md`.
- Use the issue tracker for bugs, feature ideas, and questions so we can keep conversations in one place.
- Assume good intent and prefer constructive feedback that helps others learn.

## Before You Start

1. Fork the repository and clone your fork locally.
2. Install Docker and confirm you can build the image with `docker build -t just-mobile-security-mobile-docker .`.
3. Create a branch for your work using a descriptive name, e.g. `feature/add-frida-support`.

## Reporting Bugs

1. Check existing issues to avoid duplicates.
2. Use the "Bug report" issue template and include:
   - Docker host OS and version.
   - Steps to reproduce.
   - Expected versus actual behaviour.
   - Logs or screenshots if useful.

## Requesting Enhancements

- Open an issue with the "Feature request" template.
- Explain the problem you want to solve, why it matters, and any constraints.
- Link to related standards or references (e.g. OWASP MASTG) when applicable.

## Submitting Changes

1. Update or add tests, docs, and tooling scripts as needed.
2. Run the relevant validation steps (see "Validation Checklist").
3. Push your branch and open a pull request using the provided template.
4. Link the issue you are closing with the syntax `Fixes #123`.
5. Be ready to iterate on feedback. We use review comments to reach consensus.

## Validation Checklist

- `docker build -t just-mobile-security-mobile-docker .`
- For documentation-only changes, proofread and confirm links.
- For tool updates, explain how you validated the new behaviour inside the container.

## Commit Style

- Write clear commit messages in the imperative mood (`Add tool X`).
- Keep commits focused. Bundle related changes together and avoid unrelated edits.

## Release Notes

- Add a short summary to the pull request description explaining user-facing changes.
- Highlight compatibility notes or manual steps required after upgrade.

## Getting Help

- Start a discussion in an issue if you need clarification.
- For security-sensitive questions, follow the process in `SECURITY.md`.

Thank you for contributing!
