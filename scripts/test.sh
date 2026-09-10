#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcodebuild -project Apptivator.xcodeproj -scheme Apptivator \
  -configuration Debug -destination "platform=macOS,arch=$(uname -m)" \
  -derivedDataPath build/DerivedData -clonedSourcePackagesDirPath build/SourcePackages \
  -onlyUsePackageVersionsFromResolvedFile test
