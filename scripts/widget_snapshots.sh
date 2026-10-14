#!/bin/bash
# Renders every widget size (live data) and every widget sky to PNGs.
# Usage: scripts/widget_snapshots.sh [out-dir]
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
source scripts/shared_sources.sh
OUT=${1:-widget-snapshots}
BIN=.build/widget-harness
mkdir -p .build
xcrun swiftc -O -parse-as-library -swift-version 5 -module-name CloudyHarness \
    -target arm64-apple-macos14.0 -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
    "${SHARED_SOURCES[@]}" Widgets/Provider.swift Widgets/WidgetViews.swift Widgets/Harness/SnapshotHarness.swift \
    -o "$BIN"
"$BIN" "$OUT"
