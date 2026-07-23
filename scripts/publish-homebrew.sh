#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <version> <archive-path> <tap-directory>" >&2
  exit 1
fi

version="${1#v}"
archive_path="$2"
tap_directory="$3"

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
  echo "Invalid version: $1" >&2
  exit 1
fi

if [[ ! -f "$archive_path" ]]; then
  echo "Archive not found: $archive_path" >&2
  exit 1
fi

if [[ -z "${GITHUB_REPOSITORY:-}" ]]; then
  echo "GITHUB_REPOSITORY is required" >&2
  exit 1
fi

archive="nosleep-$version.tar.gz"
url="https://github.com/${GITHUB_REPOSITORY}/releases/download/v$version/$archive"
sha256="$(sha256sum "$archive_path" | awk '{print $1}')"
formula="$tap_directory/Formula/nosleep.rb"

mkdir -p "$(dirname "$formula")"
cat > "$formula" <<FORMULA
class Nosleep < Formula
  desc "Keep your Mac awake with the lid closed"
  homepage "https://github.com/${GITHUB_REPOSITORY}"
  url "$url"
  version "$version"
  sha256 "$sha256"
  license "MIT"
  head "https://github.com/${GITHUB_REPOSITORY}.git", branch: "main"

  depends_on :macos

  def install
    bin.install "nosleep"
  end

  test do
    assert_match "Usage: nosleep", shell_output("#{bin}/nosleep --help")
  end
end
FORMULA

ruby -c "$formula"

git -C "$tap_directory" add Formula/nosleep.rb
if git -C "$tap_directory" diff --cached --quiet; then
  echo "Formula is already up to date"
  exit 0
fi

git -C "$tap_directory" config user.name "github-actions[bot]"
git -C "$tap_directory" config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git -C "$tap_directory" commit -m "Update nosleep to $version"
git -C "$tap_directory" pull --rebase
git -C "$tap_directory" push
