# Public Resources

`Public` distributes approved public copies from the configured local project workspace. Originals stay in their project repositories; this repository is never the source of truth.

## Layout

Each direct project folder in the workspace maps to a folder with the same spelling in this repository:

```text
<Project>/<slug>/
├── index.html       # HTML sources
├── original-file.pdf # other source formats
└── metadata.json
```

`Public`, `Shared`, `Archive`, and `Templates` are technical workspace folders and cannot be publication sources. Repository documentation is in `_docs/`. The legacy root HTML files are deliberately excluded from the manifest and workflow until their provenance and approval are known.

## Publish an approved file

```bash
./scripts/publish.sh <source-file> <slug>
```

For a new mapping, the script prints `<Project>/<slug>/` and requires `--confirm-new` after the user approves that target. It copies the source without modification, stores a SHA-256 hash, source repository/path/commit, public path and URL, and updates `metadata.json` plus `publish-manifest.json`. HTML is always named `index.html`; other files retain their original name. The script never commits or pushes.

## Publication status

```bash
./scripts/check-publication-status.sh <source-file>
./scripts/check-all-publications.sh
```

The single-file check returns `not-published`, `published-current`, `published-outdated`, `source-missing`, or `metadata-invalid`. The full check resolves registered source repositories below the workspace root and lists outdated files.

The local base URL is configured with:

```bash
git config public.baseUrl https://scout24-creative-ops.github.io/public/
```

## GitHub Pages

After an explicitly authorized push, enable Pages manually in the GitHub repository from `main` and `/(root)`, then verify the public URL. No GitHub setting is changed by these scripts.

## Source reconciliation — 21 November 2026

All eleven existing publications have verified source records. Public source
paths are shown only for already-public LP assets. Private source details and
historical local paths are kept in an access-controlled provenance register;
the public records expose an opaque sourceRecordId, sourceVisibility and the
Git blob identities of the files that were already public.

For a private source, the sourceRepository/sourcePath/sourceCommit values are
explicitly private and sourceAbsolutePath is not-published. These are disclosure
markers, not repository names or invented commits. An authorized user can set
PUBLIC_SOURCE_RECORDS to the private register JSON when using the existing
read-only check commands. Without it, checks report source-private or
source-registry-required rather than guessing a source.

sourceCommit denotes a verified available source snapshot, not a newly claimed
original authoring/publication commit. Three legacy CSS/JS files were recovered
exactly from the existing distribution; their original authoring sources were
not established. They are historical recovery material, not the current LP
runtime. Archived sources are not active development locations.

Public paths, URLs, publishedFiles, lastPublished, sourceHash and distributed
HTML/CSS/JS/image bytes are unchanged. This is metadata maintenance, not a
republish. The checks support both individual files and existing asset groups;
they never upload, copy, commit or publish.
