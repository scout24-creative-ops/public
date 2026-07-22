# Public repository rules

`Public` holds deliberately approved public distribution copies. It is not a source-of-truth repository.

1. Originals remain in their project repository and a publish process must never modify them.
2. Public contains only approved public copies; do not add secrets, credentials, customer data, confidential notes, or internal-only information.
3. A source's direct project folder below `/Users/dboehme/Projects` is its Public project folder. Preserve its spelling, for example `Creative Hub`.
4. `Public`, `Shared`, `Archive`, and `Templates` are not source projects and must be rejected.
5. Each publication has a stable `<Project>/<slug>/` folder. HTML is published as `index.html`; other files retain their original filename.
6. Do not use symlinks. Keep source and Public commits separate.
7. Publish only on an explicit publish request. Saving or committing a source file is never permission to publish it.
8. Do not change an established public path or URL except during an explicitly approved migration.
9. Never push automatically. Check the target repository, branch, remote, and staged changes before any user-authorized commit or push.
10. Do not remove `Shared` until its migration and references have been checked and the user explicitly approves removal.

## Codex publication workflow

When the user says “Veröffentliche diese Datei.”, resolve the active or specified source file. Ask for its exact path if ambiguous.

1. Resolve the source's direct workspace project and check `publish-manifest.json` for its repository and relative source path.
2. For a new source, derive a stable lowercase slug, state the proposed `<Project>/<slug>/` public path, and wait for confirmation.
3. For an existing unambiguous mapping, republish to its established project and slug without asking again.
4. Run `./scripts/publish.sh <source-file> <slug>`; it updates the public copy, metadata, and manifest only.
5. Run `./scripts/check-publication-status.sh <source-file>` before completing any task that edits a registered source. If it returns `published-outdated`, state: “Diese Datei wurde seit der letzten Veröffentlichung geändert. Die öffentliche Version ist noch nicht aktuell.” Then offer: “Soll ich die aktuelle Version jetzt veröffentlichen?”
6. Run the full check only when explicitly requested: `./scripts/check-all-publications.sh`.

The five legacy root HTML files remain unregistered and unmanaged until their provenance and public approval are documented. Do not move, register, republish, expose, stage, or commit them automatically.
