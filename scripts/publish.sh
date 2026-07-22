#!/usr/bin/env bash
set -euo pipefail

usage() { printf 'Usage: %s [--confirm-new] <source-file> <slug>\n' "$0" >&2; exit 64; }
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

confirm_new=false
if [[ ${1:-} == --confirm-new ]]; then confirm_new=true; shift; fi
[[ $# -eq 2 ]] || usage
source_input=$1
slug=$2
[[ "$slug" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || die 'slug must use lowercase letters, digits, and single hyphens'
[[ -f "$source_input" ]] || die "source file does not exist or is not a regular file: $source_input"

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
public_root=$(CDPATH= cd -- "$script_dir/.." && pwd -P)
workspace_root=$(CDPATH= cd -- "${PUBLIC_WORKSPACE_ROOT:-"$public_root/.."}" && pwd -P)
source_dir=$(CDPATH= cd -- "$(dirname -- "$source_input")" && pwd -P)
source_file="$source_dir/$(basename -- "$source_input")"
[[ "$source_file" == "$workspace_root"/* ]] || die "source file must be below workspace root: $workspace_root"
workspace_relative=${source_file#"$workspace_root/"}
project=${workspace_relative%%/*}
[[ "$workspace_relative" == */* ]] || die 'source file must be inside a direct workspace project folder'
case "$project" in Public|Shared|Archive|Templates) die "$project is not an allowed source project" ;; esac
[[ -d "$workspace_root/$project" ]] || die 'source project folder does not exist'

source_repository='TODO: source repository not available'
source_path="$source_file"
source_commit='TODO: source commit not available'
if git_root=$(git -C "$source_dir" rev-parse --show-toplevel 2>/dev/null); then
  source_path=${source_file#"$git_root/"}
  source_commit=$(git -C "$git_root" rev-parse HEAD 2>/dev/null || printf '%s' 'TODO: source repository has no commit')
  if remote_url=$(git -C "$git_root" remote get-url origin 2>/dev/null); then
    case "$remote_url" in
      git@github.com:*) source_repository=${remote_url#git@github.com:}; source_repository=${source_repository%.git} ;;
      https://github.com/*) source_repository=${remote_url#https://github.com/}; source_repository=${source_repository%.git} ;;
      *) source_repository="$remote_url" ;;
    esac
  fi
fi

manifest_file="$public_root/publish-manifest.json"
existing_project=$(ruby -rjson - "$manifest_file" "$source_repository" "$source_path" <<'RUBY'
manifest, repository, path = ARGV
items = JSON.parse(File.read(manifest)).fetch("publications", [])
matches = items.select { |item| item["sourceRepository"] == repository && item["sourcePath"] == path }
abort "metadata-invalid: duplicate source mapping" if matches.length > 1
puts matches.empty? ? "" : [matches.first.fetch("project"), matches.first.fetch("slug")].join("\t")
RUBY
)
registered_project=''
registered_slug=''
if [[ -n "$existing_project" ]]; then IFS=$'\t' read -r registered_project registered_slug <<< "$existing_project"; fi
[[ -z "$registered_project" || "$registered_project" == "$project" ]] || die "source is already registered in project $registered_project"
[[ -z "$registered_slug" || "$registered_slug" == "$slug" ]] || die "source is already registered at stable slug $registered_slug"

destination_dir="$public_root/$project/$slug"
case "$destination_dir" in "$public_root/$project/"*) ;; *) die 'unsafe destination path' ;; esac
if [[ -z "$registered_project" ]]; then
  printf 'Proposed new public target: %s/\n' "$project/$slug"
  [[ "$confirm_new" == true ]] || die 'new publications require explicit target confirmation; rerun with --confirm-new after approval'
fi
mkdir -p "$destination_dir"

extension=${source_file##*.}
[[ "$extension" != "$source_file" && "$extension" =~ ^[A-Za-z0-9]{1,10}$ ]] || die 'source file must have a safe extension'
extension=$(printf '%s' "$extension" | tr '[:upper:]' '[:lower:]')
case "$extension" in html|htm) published_filename='index.html' ;; *) published_filename=$(basename -- "$source_file") ;; esac
destination_file="$destination_dir/$published_filename"
cp -p "$source_file" "$destination_file"

source_hash="sha256:$(shasum -a 256 "$source_file" | awk '{print $1}')"
title=$(printf '%s' "$slug" | tr '-' ' ' | awk '{ for (i = 1; i <= NF; i++) $i = toupper(substr($i,1,1)) substr($i,2); print }')
public_path="$project/$slug/"
published_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
base_url=${PUBLIC_BASE_URL:-$(git -C "$public_root" config --get public.baseUrl 2>/dev/null || true)}
public_url='TODO: public URL not configured'
if [[ -n "$base_url" ]]; then
  encoded_project=$(ruby -ruri -e 'puts URI::DEFAULT_PARSER.escape(ARGV.fetch(0))' "$project")
  public_url="${base_url%/}/$encoded_project/$slug/"
fi

metadata_file="$destination_dir/metadata.json"
ruby -rjson - "$metadata_file" "$manifest_file" "$title" "$slug" "$project" "$source_repository" "$source_path" "$source_file" "$source_commit" "$source_hash" "$public_path" "$public_url" "$published_at" "$destination_file" <<'RUBY'
metadata_file, manifest_file, title, slug, project, repository, source_path, source_absolute_path, source_commit, source_hash, public_path, public_url, published_at, destination_file = ARGV
old = File.exist?(metadata_file) ? JSON.parse(File.read(metadata_file)) : {}
files = (old.fetch("publishedFiles", []) + [File.basename(destination_file)]).uniq.sort
metadata = {
  "title" => title, "slug" => slug, "project" => project,
  "sourceRepository" => repository, "sourcePath" => source_path,
  "sourceAbsolutePath" => source_absolute_path, "sourceCommit" => source_commit,
  "sourceHash" => source_hash, "publicPath" => public_path,
  "publicUrl" => public_url, "publishedFiles" => files,
  "lastPublished" => published_at, "status" => "published"
}
File.write(metadata_file, JSON.pretty_generate(metadata) + "\n")
manifest = JSON.parse(File.read(manifest_file))
raise "manifest version must be 2" unless manifest["version"] == 2
items = manifest.fetch("publications", [])
publication = metadata.dup
index = items.index { |item| item["sourceRepository"] == repository && item["sourcePath"] == source_path }
index ? items[index] = publication : items << publication
manifest["publications"] = items.sort_by { |item| [item["project"], item["slug"]] }
File.write(manifest_file, JSON.pretty_generate(manifest) + "\n")
RUBY

printf 'Published source copy: %s\n' "$source_file"
printf 'Updated: %s\n' "${destination_file#"$public_root/"}"
printf 'Updated: %s\n' "${metadata_file#"$public_root/"}"
printf 'Updated: publish-manifest.json\n'
case "$extension" in ppt|pptx|odp|doc|docx|odt) printf 'PDF not generated: create and review a PDF manually if needed.\n' ;; esac
printf 'No Git commit or push was performed.\n'
