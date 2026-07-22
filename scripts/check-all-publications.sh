#!/usr/bin/env bash
set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
public_root=$(CDPATH= cd -- "$script_dir/.." && pwd -P)
workspace_root=$(CDPATH= cd -- "${PUBLIC_WORKSPACE_ROOT:-"$public_root/.."}" && pwd -P)
manifest_file="$public_root/publish-manifest.json"
[[ -d "$workspace_root" ]] || { printf 'metadata-invalid: workspace root not found\n' >&2; exit 1; }

ruby -rjson - "$manifest_file" <<'RUBY' | while IFS=$'\t' read -r repository path public_path; do
manifest = JSON.parse(File.read(ARGV.fetch(0)))
raise "invalid manifest" unless manifest["version"] == 2 && manifest["publications"].is_a?(Array)
required = %w[project sourceRepository sourcePath sourceAbsolutePath sourceCommit sourceHash publicPath publicUrl lastPublished status]
manifest["publications"].each do |item|
  raise "invalid publication" unless required.all? { |field| item[field].is_a?(String) && !item[field].empty? }
  puts [item["sourceRepository"], item["sourcePath"], item["publicPath"]].join("\t")
end
RUBY
  matches=()
  while IFS= read -r git_dir; do
    repo_root=${git_dir%/.git}
    remote=$(git -C "$repo_root" remote get-url origin 2>/dev/null || true)
    case "$remote" in git@github.com:*) normalized=${remote#git@github.com:}; normalized=${normalized%.git} ;; https://github.com/*) normalized=${remote#https://github.com/}; normalized=${normalized%.git} ;; *) normalized=$remote ;; esac
    [[ "$normalized" == "$repository" ]] && matches+=("$repo_root")
  done < <(find "$workspace_root" -mindepth 2 -maxdepth 4 -type d -name .git -print)
  if [[ ${#matches[@]} -ne 1 ]]; then printf 'metadata-invalid: %s -> %s (source repository resolution failed)\n' "$repository/$path" "$public_path" >&2; continue; fi
  source_file="${matches[0]}/$path"
  status=$(/bin/bash "$script_dir/check-publication-status.sh" "$source_file")
  [[ "$status" == published-outdated ]] && printf 'published-outdated: %s -> %s\n' "$source_file" "$public_path"
  [[ "$status" == published-current ]] || [[ "$status" == published-outdated ]] || printf '%s: %s -> %s\n' "$status" "$source_file" "$public_path" >&2
done
