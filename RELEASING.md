# Releasing

Releases follow [Semantic Versioning](https://semver.org/) and are published from immutable Git tags. A tag is accepted only when its version matches `package.json`, the release is documented in `CHANGELOG.md`, and the tagged commit belongs to `main`.

## Version policy

- Patch: backward-compatible bug fixes and printer compatibility improvements.
- Minor: backward-compatible public API additions.
- Major: breaking JavaScript or native API changes, or an increased minimum React Native version.

## Release checklist

1. Start from an up-to-date, clean `main` branch.
2. Choose the version according to the policy above:

   ```sh
   npm version patch --no-git-tag-version
   ```

   Use `minor` or `major` when appropriate.

3. Add a dated entry for the version to `CHANGELOG.md`.
4. Run the complete release validation:

   ```sh
   yarn release:check
   yarn verify
   ```

5. For native transport or command changes, validate the supported Android and iOS builds and the affected physical printer models.
6. Commit the version and changelog:

   ```sh
   git add package.json CHANGELOG.md
   git commit -m "chore: release vX.Y.Z"
   git push origin main
   ```

7. After CI succeeds on `main`, create and push the annotated release tag:

   ```sh
   git tag -a vX.Y.Z -m "vX.Y.Z"
   git push origin vX.Y.Z
   ```

The tag starts `.github/workflows/release.yml`. The workflow validates the tag and package, publishes to npm through Trusted Publishing with provenance, and creates the matching GitHub release. Retrying an already-published version is safe: npm publication is skipped and the GitHub release is reconciled.

## npm setup

The npm package must trust the following GitHub Actions publisher:

- Organization or user: `richardfariax`
- Repository: `rn-escpos-printer`
- Workflow: `release.yml`
- Environment: `npm`

No long-lived npm token is stored in GitHub Actions secrets.
