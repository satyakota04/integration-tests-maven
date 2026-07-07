#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="${1:-/tmp/ti-it/order/native-agent.log}"

if [[ ! -f "$LOG_FILE" ]]; then
  echo "Log file not found: $LOG_FILE" >&2
  echo "Run order-service first with: ./run-order.sh" >&2
  exit 1
fi

echo "========================================"
echo "Class Classification Report"
echo "========================================"
echo ""

echo "User classes (isUserClass=True):"
grep "Class classification:" "$LOG_FILE" | grep "isUserClass=True" | head -20 || echo "  (none found)"

echo ""
echo "Dependency classes (isUserClass=False):"
grep "Class classification:" "$LOG_FILE" | grep "isUserClass=False" | head -20 || echo "  (none found)"

echo ""
echo "========================================"
echo "Summary"
echo "========================================"
USER_COUNT=$(grep "Class classification:" "$LOG_FILE" | grep -c "isUserClass=True" || echo "0")
DEP_COUNT=$(grep "Class classification:" "$LOG_FILE" | grep -c "isUserClass=False" || echo "0")
TOTAL=$((USER_COUNT + DEP_COUNT))

echo "Total classes classified: $TOTAL"
echo "  User classes:       $USER_COUNT"
echo "  Dependency classes: $DEP_COUNT"
echo ""

if [[ $DEP_COUNT -gt 0 ]]; then
  echo "✓ Classification is working! Dependency classes are being identified."
else
  echo "⚠ No dependency classes found. This might indicate an issue."
fi

echo ""
echo "Full log: $LOG_FILE"
