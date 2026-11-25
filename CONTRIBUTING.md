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

Update `CHANGELOG.md`, commit, then tag and push (the app's version comes from the tag):

```bash
git tag -s v1.2.3 -m "WireGuard Bar 1.2.3"
git push origin v1.2.3
```

The tag goes to both remotes, and each builds and releases it separately: GitLab CI (on the Mac runner) creates
the GitLab Release, and GitHub Actions (`.github/workflows/release.yml`) builds the DMG on GitHub's macOS runner and
publishes the GitHub Release. No tokens or secrets are needed on either side.

## Style

- Swift: follow the existing code; small files, no new dependencies.
- Commits: `type: short description` (`feat`, `fix`, `perf`, `style`, `docs`, `ci`, `refactor`).
