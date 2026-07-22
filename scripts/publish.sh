#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s [--confirm-new] <source-file> <presentations|handovers|documents> <slug>\n' "$0" >&2
  exit 64
}

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

confirm_new=false
if [[ ${1:-} == --confirm-new ]]; then confirm_new=true; shift; fi
[[ $# -eq 3 ]] || usage

source_input=$1
publication_type=$2
slug=$3
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
public_root=$(CDPATH= cd -- "$script_dir/.." && pwd -P)
manifest_file="$public_root/publish-manifest.json"

case "$publication_type" in presentations|handovers|documents) ;; *) die "type must be presentations, handovers, or documents" ;; esac
[[ "$slug" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || die "slug must use lowercase letters, digits, and single hyphens"
[[ -f "$source_input" ]] || die "source file does not exist or is not a regular file: $source_input"

source_dir=$(CDPATH= cd -- "$(dirname -- "$source_input")" && pwd -P)
source_file="$source_dir/$(basename -- "$source_input")"
[[ "$source_file" != "$public_root"/* ]] || die "source file must not be inside Public"
extension=${source_file##*.}
[[ "$extension" != "$source_file" && "$extension" =~ ^[A-Za-z0-9]{1,10}$ ]] || die "source file must have a safe extension"
extension=$(printf '%s' "$extension" | tr '[:upper:]' '[:lower:]')

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
  else
    source_repository="TODO: origin remote not configured ($(basename "$git_root"))"
  fi
fi

type_singular=${publication_type%s}
existing_mapping=$(ruby -rjson - "$manifest_file" "$source_repository" "$source_path" <<'RUBY'
manifest, repository, path = ARGV
items = JSON.parse(File.read(manifest)).fetch("publications", [])
matches = items.select { |item| item["sourceRepository"] == repository && item["sourcePath"] == path }
abort "metadata-invalid: duplicate source mapping" if matches.length > 1
puts matches.first ? [matches.first.fetch("type"), matches.first.fetch("slug")].join("\t") : ""
RUBY
)
existing_type=''
existing_slug=''
if [[ -n "$existing_mapping" ]]; then IFS=$'\t' read -r existing_type existing_slug <<< "$existing_mapping"; fi
if [[ -n "$existing_type" && "$existing_type" != "$type_singular" ]]; then die "source is already registered as type $existing_type"; fi
if [[ -n "$existing_slug" && "$existing_slug" != "$slug" ]]; then die "source is already registered at stable slug $existing_slug"; fi

destination_dir="$public_root/$publication_type/$slug"
case "$destination_dir" in "$public_root/$publication_type/"*) ;; *) die "unsafe destination path" ;; esac

if [[ -z "$existing_type" ]]; then
  printf 'Proposed new public target: %s/\n' "$publication_type/$slug"
  if [[ "$confirm_new" != true ]]; then
    die "new publications require explicit target confirmation; rerun with --confirm-new after approval"
  fi
fi

mkdir -p "$destination_dir"
destination_file="$destination_dir/$slug.$extension"
cp -p "$source_file" "$destination_file"

source_sha256=$(shasum -a 256 "$source_file" | awk '{print $1}')
title=$(printf '%s' "$slug" | tr '-' ' ' | awk '{ for (i = 1; i <= NF; i++) $i = toupper(substr($i,1,1)) substr($i,2); print }')
target_path="$publication_type/$slug/"
published_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
public_url='TODO: public URL not configured'
if [[ -n ${PUBLIC_BASE_URL:-} ]]; then
  public_url="${PUBLIC_BASE_URL%/}/$target_path"
elif configured_base_url=$(git -C "$public_root" config --get public.baseUrl 2>/dev/null); then
  public_url="${configured_base_url%/}/$target_path"
elif remote_url=$(git -C "$public_root" remote get-url origin 2>/dev/null); then
  case "$remote_url" in
    git@github.com:*|https://github.com/*)
      repo_path=${remote_url#git@github.com:}; repo_path=${repo_path#https://github.com/}; repo_path=${repo_path%.git}
      repo_owner=${repo_path%%/*}; repo_name=${repo_path#*/}
      public_url="https://${repo_owner}.github.io/${repo_name}/${target_path}"
      ;;
  esac
fi

metadata_file="$destination_dir/metadata.json"
ruby -rjson - "$metadata_file" "$manifest_file" "$title" "$slug" "$type_singular" "$source_repository" "$source_path" "$source_commit" "$source_sha256" "$target_path" "$published_at" "$public_url" "$destination_file" "$public_root" <<'RUBY'
metadata_file, manifest_file, title, slug, type, source_repository, source_path, source_commit, source_sha256, target_path, published_at, public_url, destination_file, public_root = ARGV
relative_file = File.basename(destination_file)
old = File.exist?(metadata_file) ? JSON.parse(File.read(metadata_file)) : {}
files = (old.fetch("publishedFiles", []) + [relative_file]).uniq.sort
metadata = {
  "title" => title, "slug" => slug, "type" => type,
  "sourceRepository" => source_repository, "sourcePath" => source_path,
  "sourceCommit" => source_commit, "sourceSha256" => source_sha256,
  "publicTargetPath" => target_path, "publishedFiles" => files,
  "publishedAt" => published_at, "publicUrl" => public_url, "status" => "published"
}
File.write(metadata_file, JSON.pretty_generate(metadata) + "\n")
manifest = JSON.parse(File.read(manifest_file))
raise "manifest version must be 1" unless manifest["version"] == 1
items = manifest.fetch("publications", [])
same_source = items.select { |item| item["sourceRepository"] == source_repository && item["sourcePath"] == source_path }
raise "duplicate source mapping" if same_source.length > 1
existing = items.find { |item| item["slug"] == slug && item["type"] == type }
raise "slug is already used by another source" if existing && (existing["sourceRepository"] != source_repository || existing["sourcePath"] != source_path)
publication = metadata.dup
index = items.index { |item| item["sourceRepository"] == source_repository && item["sourcePath"] == source_path }
index ? items[index] = publication : items << publication
manifest["publications"] = items.sort_by { |item| [item["type"], item["slug"]] }
File.write(manifest_file, JSON.pretty_generate(manifest) + "\n")
RUBY

printf 'Published source copy: %s\n' "$source_file"
printf 'Updated: %s\n' "${destination_file#"$public_root/"}"
printf 'Updated: %s\n' "${metadata_file#"$public_root/"}"
printf 'Updated: publish-manifest.json\n'
case "$extension" in ppt|pptx|odp|doc|docx|odt) printf 'PDF not generated: create and review a PDF manually if needed.\n' ;; esac
printf 'No Git commit or push was performed.\n'
