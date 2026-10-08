#!/bin/bash
# Compile Foundation-only sources + the XCTest file into one macOS test bundle, no SwiftPM.
set -e
OUT=$(mktemp -d)
mkdir -p "$OUT/LenientMessageTests.xctest/Contents/MacOS"
DEV=$(xcode-select -p)/Platforms/MacOSX.platform/Developer
swiftc -emit-library -parse-as-library -module-name LenientMessageTests -swift-version 5 \
  -F "$DEV/Library/Frameworks" -I "$DEV/usr/lib" -L "$DEV/usr/lib" -Xlinker -rpath -Xlinker "$DEV/Library/Frameworks" \
  Sources/LenientMessage/*.swift Tests/LenientMessageTests/*.swift \
  -o "$OUT/LenientMessageTests.xctest/Contents/MacOS/LenientMessageTests"
xcrun xctest "$OUT/LenientMessageTests.xctest"
