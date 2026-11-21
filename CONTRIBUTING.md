# Contributing to RideSync

Thanks for your interest in improving RideSync. This guide explains how to propose changes.

## Ways to contribute

- **Report a bug:** open an issue using the [bug report template](https://github.com/SaiVarun-26/Ridesync/issues/new?template=bug_report.yml).
- **Suggest a feature:** open an issue using the [feature request template](https://github.com/SaiVarun-26/Ridesync/issues/new?template=feature_request.yml).
- **Improve the code or docs:** open a pull request.

For anything larger than a small fix, please open an issue first so the change can be discussed before you spend time on it.

## Development setup

1. Install the [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel).
2. Fork and clone the repository.
3. Connect your own Firebase project (see [Getting Started](README.md#getting-started)).
4. Install dependencies and run:
   ```bash
   flutter pub get
   flutter run
   ```

## Making a change

1. Create a branch from `main`:
   ```bash
   git checkout -b feature/short-description
   ```
2. Follow the existing architecture: feature-first folders under `lib/features/`, each split into `data`, `domain` and `presentation`. Keep domain code free of Flutter and Firebase.
3. Match the existing code style; `analysis_options.yaml` defines the lint rules.
4. Before opening a pull request, make sure these pass:
   ```bash
   flutter analyze
   flutter test
   ```

## Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org/):

| Type | Use for |
|---|---|
| `feat:` | A new feature |
| `fix:` | A bug fix |
| `perf:` | A performance improvement |
| `refactor:` | Code changes that neither fix a bug nor add a feature |
| `docs:` | Documentation only |
| `test:` | Tests only |
| `chore:` | Build, tooling and maintenance |

Example: `feat: add ride challenges`

## Pull requests

- Keep each pull request focused on one change.
- Describe what changed and why, and link the related issue.
- Add screenshots or a short screen recording for UI changes.
- Never commit APKs, keystores, `key.properties` or other secrets.

## Releases

Releases are published by the maintainers. A release bumps `version` in `pubspec.yaml`, adds a section to [CHANGELOG.md](CHANGELOG.md), and pushes a matching `vX.Y.Z` tag. The [release workflow](.github/workflows/release.yml) then builds the APK and publishes it on [GitHub Releases](https://github.com/SaiVarun-26/Ridesync/releases).

## Code of conduct

By taking part you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).
