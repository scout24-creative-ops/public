# Public Resources

This repository holds approved public copies of resources from the Creative Ops workspace. It is intentionally static: no framework, build process, automatic deployment, commit, or push is used.

Existing HTML files in this repository predate the manifest workflow. Their source repository, approval state, and stable destination are not yet documented, so they are not listed in `publish-manifest.json`. Review them before treating them as managed publications or exposing the repository publicly.

## Publishing an approved copy

Run from this repository:

```bash
./scripts/publish.sh <source-file> <type> <slug>
```

For example:

```bash
./scripts/publish.sh \
  ../Creative\ Hub/docs/presentations/creative-hub-overview.pptx \
  presentations \
  creative-hub-overview
```

The source file is copied without modification to a stable folder such as `presentations/creative-hub-overview/`. The script records the source repository and path, source Git commit when available, SHA-256 source hash, publication time, public target path, and public URL when it can be determined. It adds or updates `metadata.json` and `publish-manifest.json`; it does not create a Git commit, push, or convert documents silently. Review public suitability before running it.

For a new source-to-target mapping, the script requires a confirmation after printing the proposed target. Use `--confirm-new` only after that target has been explicitly approved. Existing mappings may be republished directly.

## Publication status

```bash
./scripts/check-publication-status.sh <source-file>
./scripts/check-all-publications.sh
```

The first command returns one of `not-published`, `published-current`, `published-outdated`, `source-missing`, or `metadata-invalid`. The second resolves registered repositories below the workspace root (the parent of `Public`) and lists only outdated items with their source and public target path. Set `PUBLIC_WORKSPACE_ROOT` if the workspace is elsewhere.

The planned base URL is stored locally in the repository configuration as `public.baseUrl`. Configure it with:

```bash
git config public.baseUrl https://scout24-creative-ops.github.io/public/
```

`PUBLIC_BASE_URL` overrides that local value for a single invocation. If neither is set, a GitHub Pages URL is derived when `origin` is a GitHub repository; otherwise metadata visibly marks the URL as still to be configured.

## GitHub Pages setup (manual, after approval)

1. Create the repository `scout24-creative-ops/public` on GitHub.
2. Connect this local repository to that remote.
3. Review changes and create a local commit.
4. Push only after explicit approval.
5. In GitHub, enable Pages from the `main` branch and the repository root.
6. Verify the public URL and links.
7. Only then publish the first real, approved content.

GitHub Pages is not configured by this repository. `index.html` reads the manifest in the same directory and works when served from the Pages root.
