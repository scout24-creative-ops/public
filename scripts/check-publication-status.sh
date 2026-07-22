#!/usr/bin/env bash
set -euo pipefail

[[ $# -eq 1 ]] || { printf 'Usage: %s <source-file>\n' "$0" >&2; exit 64; }
source_input=$1
[[ -f "$source_input" ]] || { printf 'source-missing\n'; exit 0; }
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
public_root=$(CDPATH= cd -- "$script_dir/.." && pwd -P)
source_dir=$(CDPATH= cd -- "$(dirname -- "$source_input")" && pwd -P)
source_file="$source_dir/$(basename -- "$source_input")"
repository='TODO: source repository not available'
relative_path="$source_file"
if git_root=$(git -C "$source_dir" rev-parse --show-toplevel 2>/dev/null); then
  relative_path=${source_file#"$git_root/"}
  if remote_url=$(git -C "$git_root" remote get-url origin 2>/dev/null); then
    case "$remote_url" in
      git@github.com:*) repository=${remote_url#git@github.com:}; repository=${repository%.git} ;;
      https://github.com/*) repository=${remote_url#https://github.com/}; repository=${repository%.git} ;;
      *) repository="$remote_url" ;;
    esac
  fi
fi

ruby -rjson -rshellwords - "$public_root/publish-manifest.json" "$repository" "$relative_path" "$source_file" <<'RUBY'
manifest_file, repository, relative_path, source_file = ARGV
begin
  manifest = JSON.parse(File.read(manifest_file))
  raise unless manifest["version"] == 2 && manifest["publications"].is_a?(Array)
  matches = manifest["publications"].select { |item| item["sourceRepository"] == repository && item["sourcePath"] == relative_path }
  raise if matches.length > 1
  if matches.empty? then puts "not-published"; exit end
  item = matches.first
  required = %w[project sourceRepository sourcePath sourceAbsolutePath sourceCommit sourceHash publicPath publicUrl lastPublished status]
  raise unless required.all? { |field| item[field].is_a?(String) && !item[field].empty? }
  raise unless item["publicPath"] == "#{item["project"]}/#{item["slug"]}/" && !item["project"].include?("/")
  metadata = JSON.parse(File.read(File.join(File.dirname(manifest_file), item["publicPath"], "metadata.json")))
  raise unless required.all? { |field| metadata[field] == item[field] }
  current_hash = "sha256:" + `shasum -a 256 #{Shellwords.escape(source_file)}`.split.first.to_s
  puts current_hash == item["sourceHash"] ? "published-current" : "published-outdated"
rescue StandardError
  puts "metadata-invalid"
end
RUBY
