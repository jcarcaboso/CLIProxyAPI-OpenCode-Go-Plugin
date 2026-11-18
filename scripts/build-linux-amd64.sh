#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
version=$(sed -nE 's/^[[:space:]]*pluginVersion = "([^"]+)"$/\1/p' "$root/main.go")
test -n "$version"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/CLIProxyAPI" "$work/plugin" "$work/package"
# The Go module expects the CLIProxyAPI source in a sibling directory.
curl -fsSL https://codeload.github.com/router-for-me/CLIProxyAPI/tar.gz/c19787b25262b5e6e46a9e8da62f4333e7e478bc \
  | tar -xz --strip-components=1 -C "$work/CLIProxyAPI"
git -C "$root" archive HEAD | tar -x -C "$work/plugin"
cp "$work/plugin/LICENSE" "$work/package/"

docker run --rm --platform linux/amd64 \
  --mount "type=bind,src=$work,dst=/src" --workdir /src/plugin \
  -e GOOS=linux -e GOARCH=amd64 -e GOAMD64=v1 -e CGO_ENABLED=1 \
  -e 'CGO_CFLAGS=-O2 -g -march=x86-64' \
  docker.io/library/golang@sha256:dc40a13b61304647ed7e5d581d246b86413dfc29d63c6d018310feb93cd98fc0 \
  go build -mod=mod -trimpath -buildvcs=false -buildmode=c-shared -o /src/package/opencode-go-oauth.so .

out="$root/dist"
archive="opencode-go-oauth_${version}_linux_amd64.zip"
mkdir -p "$out"
rm -f "$out/$archive"
(cd "$work/package" && python3 -m zipfile -c "$out/$archive" opencode-go-oauth.so LICENSE)
(cd "$out" && sha256sum "$archive" > checksums.txt)
