# Contributing

The main repository is on GitLab: <https://gitlab.com/PioneerSwine996/wireguard>.
GitHub (<https://github.com/PioneerSwine996/wireguard-bar-macos>) is a read-only mirror that accepts pull requests.

## Opening a pull request

1. Fork the GitHub mirror and branch from `main`.
2. Keep changes focused; one feature or fix per pull request.
3. Run the tests and build before pushing:

   ```bash
   swift test
   scripts/build-app.sh
   ```

4. If you change `scripts/wgbar-helper` or anything it runs as root, say so in the pull request and explain how
   inputs are validated. The helper runs as root without a password prompt, so it gets the closest review.
5. Open the pull request against `main`. GitHub Actions builds and tests it on macOS.

Merge requests on GitLab are welcome too.

## How pull requests are merged (maintainers)

GitLab pushes `main` to GitHub, so don't merge with GitHub's button: the next mirror push would overwrite it.
Instead, land the pull request through GitLab:

```bash
git fetch github pull/<number>/head:pr-<number>
git checkout main
git merge --ff-only pr-<number>     # or rebase it onto main first
git push origin main
```

When the mirror pushes `main`, GitHub sees the pull request's commits on `main` and marks it merged.

## Releasing (maintainers)

Update `CHANGELOG.md` and the version in `scripts/build-app.sh`, commit, then tag and push:

```bash
git tag -s v1.2.3 -m "WireGuard Bar 1.2.3"
git push origin v1.2.3
```

CI builds the DMG, creates the GitLab Release, and publishes the same release with `WireGuardBar.dmg` on GitHub.
One-time setup: a fine-grained GitHub token with Contents read/write on `wireguard-bar-macos`, stored in GitLab as
the masked, protected CI/CD variable `GITHUB_RELEASE_TOKEN`, and `v*` added under Settings → Repository →
Protected tags.

## Style

- Swift: follow the existing code; small files, no new dependencies.
- Commits: `type: short description` (`feat`, `fix`, `perf`, `style`, `docs`, `ci`, `refactor`).
