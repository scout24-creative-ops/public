# Public repository rules

`Public` is a repository of deliberately approved, public publication copies.

1. Original files remain in their respective project repository.
2. `Public` contains only approved publication copies.
3. Published copies are never the source of truth.
4. Every publication must have a traceable connection to its source.
5. Public target paths and URLs must remain stable when content is updated.
6. Publish only after an explicit publish request.
7. Before every publication, verify that the content may be public.
8. Commit changes in the project repository and in `Public` separately.
9. Never push automatically.
10. Do not use symlinks between repositories.
11. A publish process must not modify source files.
12. Do not remove `Shared` until migration and reference checks are complete.

## Commands

- `Publish <source-path> as <destination-slug>` — publish an approved source copy with `./scripts/publish.sh <source-path> <type> <destination-slug>`.
- `Republish <source-path>` — refresh the existing approved publication after resolving its type and slug from its metadata.
- `Unpublish <destination-slug>` — remove a public publication only after an explicit unpublish request and a dependency check; no unpublish script is provided to avoid accidental removal.

The type must be one of `presentations`, `handovers`, or `documents`. Review the source, destination, and generated metadata before committing. The script never commits or pushes.

## Codex publication workflow

When the user says “Veröffentliche diese Datei.”, identify the active or explicitly referenced file. If that file is not unambiguous, ask for its exact path.

1. Resolve the source repository and relative source path.
2. Check `publish-manifest.json` for that source.
3. For a new source, derive an allowed type and stable lowercase slug. State the proposed public target path and wait for the user's confirmation before publishing.
4. For an existing, unambiguous source-to-target mapping, republish without asking for the target again.
5. Run `scripts/publish.sh`; do not alter the source file. Only create additional formats when a reliable, reviewed conversion is available.
6. Review the output for obvious sensitive material before publication. Stop for clarification if the content appears to contain credentials, personal data, customer data, confidential notes, or internal-only information.
7. During the current setup phase, do not commit, push, or publish externally. After the user explicitly releases the workflow for normal use, Public commits and pushes may be made only as separate actions from source-repository commits, and only when the Public remote and permissions are verified.

When Codex edits a file already registered in `publish-manifest.json`, it must run `./scripts/check-publication-status.sh <source-file>` before completing the task. If the result is `published-outdated`, state exactly: “Diese Datei wurde seit der letzten Veröffentlichung geändert. Die öffentliche Version ist noch nicht aktuell.” Then offer: “Soll ich die aktuelle Version jetzt veröffentlichen?” Do not publish merely because a file was saved or committed.

Do not run a full-publication scan for unrelated work. Use `./scripts/check-all-publications.sh` only for an explicit status request or a deliberate full check.

The five legacy root HTML files are not registered or managed publications until their source and public approval are documented. Do not move, register, republish, or expose them automatically.
