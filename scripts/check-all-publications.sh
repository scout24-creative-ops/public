#!/usr/bin/env bash
set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
public_root=$(CDPATH= cd -- "$script_dir/.." && pwd -P)
workspace_root=${PUBLIC_WORKSPACE_ROOT:-"$public_root/.."}
manifest_file="$public_root/publish-manifest.json"

[[ -d "$workspace_root" ]] || { printf 'metadata-invalid: workspace root not found: %s\n' "$workspace_root" >&2; exit 1; }
ruby -rjson - "$manifest_file" <<'RUBY' | while IFS=$'\t' read -r repository path target; do
manifest = JSON.parse(File.read(ARGV.fetch(0)))
raise "invalid manifest" unless manifest["version"] == 1 && manifest["publications"].is_a?(Array)
required = %w[sourceRepository sourcePath sourceCommit sourceSha256 publicTargetPath publishedAt publicUrl status]
manifest["publications"].each do |item|
  raise "invalid publication" unless required.all? { |field| item[field].is_a?(String) && !item[field].empty? }
  raise "invalid target" unless item["publicTargetPath"].match?(%r{\A(?:presentations|handovers|documents)/[a-z0-9]+(?:-[a-z0-9]+)*/\z})
  puts [item["sourceRepository"], item["sourcePath"], item["publicTargetPath"]].join("\t")
end
RUBY
  matches=()
  while IFS= read -r git_dir; do
    repo_root=${git_dir%/.git}
    remote=$(git -C "$repo_root" remote get-url origin 2>/dev/null || true)
    case "$remote" in
      git@github.com:*) normalized=${remote#git@github.com:}; normalized=${normalized%.git} ;;
      https://github.com/*) normalized=${remote#https://github.com/}; normalized=${normalized%.git} ;;
      *) normalized=$remote ;;
    esac
    [[ "$normalized" == "$repository" ]] && matches+=("$repo_root")
  done < <(find "$workspace_root" -mindepth 2 -maxdepth 2 -type d -name .git -print)
  if [[ ${#matches[@]} -ne 1 ]]; then
    printf 'metadata-invalid: %s -> %s (source repository resolution failed)\n' "$repository/$path" "$target" >&2
    continue
  fi
  source_file="${matches[0]}/$path"
  status=$(/bin/bash "$script_dir/check-publication-status.sh" "$source_file")
  if [[ "$status" == published-outdated ]]; then
    printf 'published-outdated: %s -> %s\n' "$source_file" "$target"
  elif [[ "$status" != published-current ]]; then
    printf '%s: %s -> %s\n' "$status" "$source_file" "$target" >&2
  fi
done
