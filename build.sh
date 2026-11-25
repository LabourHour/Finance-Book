#!/usr/bin/env bash
# Stream Flutter 迁移 - 编译级检查（仅编译/分析，不跑测试）
set -o pipefail
export PATH="/c/flutter/bin:$PATH"

echo "== flutter analyze =="
flutter analyze --no-pub 2>&1 | tail -40
ANALYZE_STATUS=${PIPESTATUS[0]}

echo "== flutter build apk --debug =="
timeout 900 flutter build apk --debug --no-pub 2>&1 | tail -40
BUILD_STATUS=$?

echo "analyze_status=$ANALYZE_STATUS build_status=$BUILD_STATUS"
if [ "$ANALYZE_STATUS" -ne 0 ]; then
  exit 1
fi
exit 0