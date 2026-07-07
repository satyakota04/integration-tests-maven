#!/usr/bin/env bash
set -euo pipefail

echo "========================================"
echo "Classification Report - All Services"
echo "========================================"
echo ""

check_service() {
  local service=$1
  local log_file="/tmp/ti-it/$service/native-agent.log"

  if [[ ! -f "$log_file" ]]; then
    echo "[$service] ⚠ No log file found at $log_file"
    return
  fi

  local user_count=$(grep "Class classification:" "$log_file" | grep -c "isUserClass=True" || echo "0")
  local dep_count=$(grep "Class classification:" "$log_file" | grep -c "isUserClass=False" || echo "0")
  local total=$((user_count + dep_count))

  echo "[$service]"
  echo "  Total classified: $total"
  echo "  User classes:     $user_count"
  echo "  Dependency:       $dep_count"

  if [[ $dep_count -gt 0 ]]; then
    echo "  Status: ✓ Classification working"
  else
    echo "  Status: ⚠ No dependencies classified"
  fi
  echo ""
}

check_service "order"
check_service "inventory"
check_service "shipping"

echo "========================================"
echo "Sample User Classes"
echo "========================================"
grep "Class classification:" /tmp/ti-it/*/native-agent.log 2>/dev/null | \
  grep "isUserClass=True" | \
  grep "com.harness.sample" | \
  head -10 || echo "No user classes found"

echo ""
echo "========================================"
echo "Sample Dependency Classes"
echo "========================================"
grep "Class classification:" /tmp/ti-it/*/native-agent.log 2>/dev/null | \
  grep "isUserClass=False" | \
  head -15 || echo "No dependency classes found"

echo ""
echo "========================================"
echo "Log Files"
echo "========================================"
echo "Order:     /tmp/ti-it/order/native-agent.log"
echo "Inventory: /tmp/ti-it/inventory/native-agent.log"
echo "Shipping:  /tmp/ti-it/shipping/native-agent.log"
