#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# An optional release tag sets the version inside the app as well as artifact names.
tag="${1:-}"
version_args=("CODE_SIGN_IDENTITY=-")
if [[ -n "$tag" ]]; then
  if [[ ! "$tag" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
    echo "Expected a release tag in the form v1.2.3, got: $tag" >&2
    exit 1
  fi
  if [[ -z "${CODE_SIGN_IDENTITY:-}" || "$CODE_SIGN_IDENTITY" == - ]]; then
    echo 'Release packages require scripts/with-code-signing-identity.sh in CI.' >&2
    exit 1
  fi
  version_args+=("MARKETING_VERSION=${tag#v}")
fi
if [[ -n "${GITHUB_RUN_NUMBER:-}" ]]; then
  version_args+=("CURRENT_PROJECT_VERSION=$GITHUB_RUN_NUMBER")
fi

xcodebuild -project Apptivator.xcodeproj -scheme Apptivator \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath build/DerivedData -clonedSourcePackagesDirPath build/SourcePackages \
  -onlyUsePackageVersionsFromResolvedFile -archivePath build/Apptivator.xcarchive \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
  "${version_args[@]}" archive

app=build/Apptivator.xcarchive/Products/Applications/Apptivator.app
# Reject Intel-only artifacts, including any nested executables or libraries.
while IFS= read -r -d '' binary; do
  if file -b "$binary" | grep -q 'Mach-O'; then
    lipo "$binary" -verify_arch arm64 x86_64
  fi
done < <(find "$app" -type f -print0)
lipo -archs "$app/Contents/MacOS/Apptivator"
if [[ -n "${CODE_SIGN_IDENTITY:-}" && "$CODE_SIGN_IDENTITY" != - ]]; then
  : "${CODE_SIGN_KEYCHAIN:?Use scripts/with-code-signing-identity.sh in CI}"
  : "${CODE_SIGN_REQUIREMENTS:?The stable designated requirement is required}"
  : "${CODE_SIGN_REQUIREMENT:?The stable verification requirement is required}"
  codesign --force --sign "$CODE_SIGN_IDENTITY" --keychain "$CODE_SIGN_KEYCHAIN" \
    --requirements "$CODE_SIGN_REQUIREMENTS" --timestamp=none "$app"
  codesign --verify --deep --strict --test-requirement "=$CODE_SIGN_REQUIREMENT" "$app"
  codesign --display --requirements - "$app"
else
  # Ad-hoc signing is only for development/PR builds, never tagged releases.
  if [[ -n "$tag" ]]; then
    echo 'Release packages require the long-lived CI signing identity.' >&2
    exit 1
  fi
  codesign --verify --deep --strict "$app"
fi

version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")
name="Apptivator-${version}-universal"
mkdir -p dist
staging=$(mktemp -d "${TMPDIR:-/tmp}/apptivator-dmg.XXXXXX")
trap 'rm -rf "$staging"' EXIT
ditto "$app" "$staging/Apptivator.app"
ln -s /Applications "$staging/Applications"
ditto -c -k --sequesterRsrc --keepParent "$app" "dist/$name.zip"
hdiutil create -volname Apptivator -srcfolder "$staging" -ov -format UDZO "dist/$name.dmg"
(cd dist && shasum -a 256 "$name.zip" "$name.dmg" > "$name-SHA256SUMS.txt")
