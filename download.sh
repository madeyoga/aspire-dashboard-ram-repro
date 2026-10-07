#!/usr/bin/env bash
# Download Aspire NuGet packages used by this reproduction.
# VERSION defaults to 13.6.0. Set DOWNLOAD_CLI=1 to also fetch the CLI packages
# (pointer + linux-x64) for the on-disk size comparison in the README.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
VERSION="${VERSION:-13.6.0}"
BASE="https://api.nuget.org/v3-flatcontainer"

fetch() {
  local id="$1"
  local lower
  lower=$(printf '%s' "$id" | tr '[:upper:]' '[:lower:]')
  local nupkg="${lower}.${VERSION}.nupkg"
  local url="${BASE}/${lower}/${VERSION}/${nupkg}"
  echo "Downloading ${id} ${VERSION}..."
  curl -fsSL -o "$nupkg" "$url"
  local dest="${lower}"
  rm -rf "$dest"
  mkdir -p "$dest"
  unzip -q "$nupkg" -d "$dest"
  if [[ -f "$dest/tools/Aspire.Dashboard" ]]; then
    chmod +x "$dest/tools/Aspire.Dashboard"
  fi
  if [[ -f "$dest/tools/aspire" ]]; then
    chmod +x "$dest/tools/aspire"
  fi
  echo "  -> ${nupkg} ($(du -h "$nupkg" | awk '{print $1}')) unpacked to ${dest}/"
}

fetch Aspire.Dashboard.Sdk.linux-x64

if [[ "${DOWNLOAD_CLI:-0}" == "1" ]]; then
  fetch Aspire.Cli
  fetch Aspire.Cli.linux-x64
fi

echo "Done. Dashboard binary: ${ROOT}/aspire.dashboard.sdk.linux-x64/tools/Aspire.Dashboard"
