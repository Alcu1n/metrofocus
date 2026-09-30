#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
SIMULATOR_ID="${1:?Usage: scripts/verify.sh simulator-uuid [result-name]}"
RESULT_NAME="${2:-acceptance-$(date +%Y%m%d-%H%M%S)}"
xcodebuild test -project MetroFocus.xcodeproj -scheme MetroFocus \
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
  -derivedDataPath build/DerivedData -parallel-testing-enabled NO \
  -collect-test-diagnostics never \
  -resultBundlePath "artifacts/$RESULT_NAME.xcresult" \
  CODE_SIGNING_ALLOWED=NO | tee "artifacts/$RESULT_NAME.log"
