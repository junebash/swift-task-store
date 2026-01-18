# Commit Convention

This project uses [Conventional Commits](https://www.conventionalcommits.org/) to automate versioning and changelog generation.

## Format

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

## Types

| Type | Description | Version Bump |
|------|-------------|--------------|
| `feat` | New feature | Minor |
| `fix` | Bug fix | Patch |
| `docs` | Documentation only | Patch |
| `style` | Code style (formatting) | Patch |
| `refactor` | Code refactoring | Patch |
| `perf` | Performance improvement | Patch |
| `test` | Adding/fixing tests | Patch |
| `chore` | Maintenance tasks | Patch |
| `ci` | CI/CD changes | Patch |

## Breaking Changes

Add `!` after type or include `BREAKING CHANGE:` in footer for major version bump:

```
feat!: change addTask return type

BREAKING CHANGE: addTask now returns Task<Void, Error> instead of Task<Void, Never>.
```

## Examples

```
feat: add timeout parameter to addTask

fix: resolve race condition in task cleanup

docs: update README with duplicate key behavior examples

chore: update Swift tools version to 6.2

refactor: simplify TaskData internal structure
```
