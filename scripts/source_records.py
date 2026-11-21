"""Read-only publication checks with optional private source resolution."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def git(root, *args):
    return subprocess.check_output(
        ["git", "-C", str(root), *args], text=True,
        stderr=subprocess.DEVNULL).strip()


def load():
    manifest = json.loads((ROOT / "publish-manifest.json").read_text())
    if manifest.get("version") != 2:
        raise ValueError("metadata-invalid")
    register = {}
    if os.environ.get("PUBLIC_SOURCE_RECORDS"):
        data = json.loads(Path(os.environ["PUBLIC_SOURCE_RECORDS"]).read_text())
        if data.get("version") != 1 or not isinstance(data.get("records"), dict):
            raise ValueError("metadata-invalid")
        register = data["records"]
    items = manifest["publications"]
    for item in items:
        folder = safe_path(ROOT, item["publicPath"])
        if item != json.loads((folder / "metadata.json").read_text()):
            raise ValueError("metadata-invalid")
    return items, register


def safe_path(root, path):
    relative = Path(path)
    if relative.is_absolute() or ".." in relative.parts:
        raise ValueError("metadata-invalid")
    target = (root / relative).resolve()
    if not target.is_relative_to(root.resolve()):
        raise ValueError("metadata-invalid")
    return target


def resolve(item, register):
    if item.get("sourceVisibility") != "private":
        return item
    entry = register.get(item.get("sourceRecordId"))
    if entry is None:
        return None
    public_files = item["sourceReconciliation"]["files"]
    private_files = entry["sourceReconciliation"]["files"]
    if [(x["publishedFile"], x["gitBlob"]) for x in public_files] != [
            (x["publishedFile"], x["gitBlob"]) for x in private_files]:
        raise ValueError("metadata-invalid")
    return {**item, **entry}


def repository(root):
    remote = git(root, "remote", "get-url", "origin")
    if remote.startswith("git@github.com:"):
        return remote[len("git@github.com:"):].removesuffix(".git")
    if remote.startswith("https://github.com/"):
        return remote[len("https://github.com/"):].removesuffix(".git")
    return remote


def status(item, source_root):
    files = item.get("sourceReconciliation", {}).get("files")
    if files:
        changed = False
        for entry in files:
            path = safe_path(source_root, entry["sourcePath"])
            if not path.is_file():
                return "source-missing"
            blob = entry["gitBlob"]
            if not re.fullmatch(r"[0-9a-f]{40}", blob):
                raise ValueError("metadata-invalid")
            data = path.read_bytes()
            digest = hashlib.sha1(
                b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
            changed |= digest != blob
        return "published-outdated" if changed else "published-current"
    # Existing future single-file publications retain the original v2 hash contract.
    source = safe_path(source_root, item["sourcePath"])
    if not source.is_file():
        return "source-missing"
    digest = "sha256:" + hashlib.sha256(source.read_bytes()).hexdigest()
    return "published-current" if digest == item["sourceHash"] else "published-outdated"


def check_file(path, items, register):
    source = path.resolve()
    if not source.is_file():
        return "source-missing"
    try:
        root = Path(git(source.parent, "rev-parse", "--show-toplevel"))
        name = repository(root)
    except subprocess.CalledProcessError:
        return "source-registry-required" if any(
            x.get("sourceVisibility") == "private" for x in items) else "not-published"
    relative = source.relative_to(root).as_posix()
    candidates = []
    unresolved = False
    for item in items:
        resolved = resolve(item, register)
        if resolved is None:
            unresolved = True
            continue
        prefix = resolved["sourcePath"]
        if resolved["sourceRepository"] == name and (
                relative == prefix or prefix.endswith("/") and relative.startswith(prefix)):
            candidates.append(resolved)
    if len(candidates) > 1:
        raise ValueError("metadata-invalid")
    if not candidates:
        return "source-registry-required" if unresolved else "not-published"
    return status(candidates[0], root)


def repositories(workspace):
    result = {}
    for directory, children, files in os.walk(workspace):
        path = Path(directory)
        if ".git" in children or ".git" in files:
            try:
                result.setdefault(repository(path), []).append(path)
            except subprocess.CalledProcessError:
                pass
            children[:] = []
        elif len(path.relative_to(workspace).parts) >= 4:
            children[:] = []
    return result


def check_all(workspace, items, register):
    roots = repositories(workspace)
    results = []
    for item in items:
        resolved = resolve(item, register)
        if resolved is None:
            results.append(("source-private", item["publicPath"]))
            continue
        matches = roots.get(resolved["sourceRepository"], [])
        result = status(resolved, matches[0]) if len(matches) == 1 else "source-missing"
        results.append((result, item["publicPath"]))
    return results


def main():
    try:
        items, register = load()
        if len(sys.argv) == 3 and sys.argv[1] == "file":
            print(check_file(Path(sys.argv[2]), items, register))
        elif len(sys.argv) == 2 and sys.argv[1] == "all":
            workspace = Path(os.environ.get("PUBLIC_WORKSPACE_ROOT", ROOT.parent)).resolve()
            if not workspace.is_dir():
                raise ValueError("metadata-invalid")
            for result, public_path in check_all(workspace, items, register):
                print(result + ": " + public_path)
        else:
            print("Usage: source_records.py file <source-file> | all", file=sys.stderr)
            return 64
    except (ValueError, KeyError, OSError, TypeError):
        # Do not expose private register paths or source locations in public output.
        print("metadata-invalid")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
