#!/usr/bin/env bash
# Expose the locally-running services (8081/8082/8083) via public tunnels so a
# remote CI pipeline can run hcli integration tests against them.
#
# Default provider: ngrok using RESERVED domains from your ngrok.yml
# (~/Library/Application Support/ngrok/ngrok.yml). Reserved domains give stable
# URLs so you don't have to copy them each run. The named tunnels 'order',
# 'inventory', 'shipping' must exist in that config (added there already).
#
# Assumes the services are already running on the PC (run-order.sh / run-inventory.sh
# / run-shipping.sh, or run-all-services.sh). Inter-service calls stay on localhost.
#
# Output: prints the 3 public URLs and writes them to tunnel-urls.txt. Keep this
# terminal open for the whole CI run; Ctrl-C stops the tunnels.
#
# Bash 3.2 compatible (no associative arrays / mapfile) for macOS default bash.
set -euo pipefail

PROVIDER="${TUNNEL_PROVIDER:-ngrok}"
URL_FILE="${TUNNEL_URL_FILE:-tunnel-urls.txt}"

ORDER_PORT="${ORDER_PORT:-8081}"
INVENTORY_PORT="${INVENTORY_PORT:-8082}"
SHIPPING_PORT="${SHIPPING_PORT:-8083}"

# Reserved ngrok domains (stable URLs). Override via env if you rename them.
NGROK_CONFIG="${NGROK_CONFIG:-$HOME/Library/Application Support/ngrok/ngrok.yml}"
ORDER_DOMAIN="${ORDER_DOMAIN:-order-kota.ngrok-free.dev}"
INVENTORY_DOMAIN="${INVENTORY_DOMAIN:-inventory-kota.ngrok-free.dev}"
SHIPPING_DOMAIN="${SHIPPING_DOMAIN:-shipping-kota.ngrok-free.dev}"

URL_ORDER=""
URL_INVENTORY=""
URL_SHIPPING=""

PIDS=()
cleanup() {
  echo ""
  echo "==> Stopping tunnels..."
  for pid in ${PIDS[@]+"${PIDS[@]}"}; do kill "$pid" 2>/dev/null || true; done
  pkill -f "ngrok start order inventory shipping" 2>/dev/null || true
  pkill -f "cloudflared tunnel --url http://localhost:80" 2>/dev/null || true
  echo "Stopped."
}
trap cleanup EXIT

require() { command -v "$1" >/dev/null 2>&1 || { echo "Missing required tool: $1" >&2; exit 1; }; }

echo "========================================"
echo "Tunnel services  (provider: $PROVIDER)"
echo "  order     -> :$ORDER_PORT"
echo "  inventory -> :$INVENTORY_PORT"
echo "  shipping  -> :$SHIPPING_PORT"
echo "========================================"
echo ""

case "$PROVIDER" in
  ngrok)
    require ngrok
    if [[ ! -f "$NGROK_CONFIG" ]]; then
      echo "ngrok config not found: $NGROK_CONFIG" >&2
      echo "Set NGROK_CONFIG to your ngrok.yml path." >&2
      exit 1
    fi
    echo "Using ngrok config: $NGROK_CONFIG"
    echo "Starting reserved-domain tunnels: order inventory shipping..."
    ngrok start order inventory shipping --config "$NGROK_CONFIG" >/tmp/it-ngrok.log 2>&1 &
    PIDS+=($!)
    sleep 4

    # Reserved domains => URLs are known/stable, no API parsing needed.
    URL_ORDER="https://$ORDER_DOMAIN"
    URL_INVENTORY="https://$INVENTORY_DOMAIN"
    URL_SHIPPING="https://$SHIPPING_DOMAIN"

    # Sanity check the ngrok process is still alive (fails fast on bad config/auth).
    if ! kill -0 "${PIDS[0]}" 2>/dev/null; then
      echo "ngrok exited early. Log:" >&2
      cat /tmp/it-ngrok.log >&2
      exit 1
    fi
    ;;

  cloudflared)
    require cloudflared
    for svc in order inventory shipping; do
      case "$svc" in
        order) port=$ORDER_PORT ;;
        inventory) port=$INVENTORY_PORT ;;
        shipping) port=$SHIPPING_PORT ;;
      esac
      log="/tmp/it-cf-$svc.log"
      echo "Starting cloudflared for $svc (port $port)..."
      cloudflared tunnel --url "http://localhost:$port" --loglevel info >"$log" 2>&1 &
      PIDS+=($!)
    done
    echo "Waiting for tunnel URLs..."
    for _ in $(seq 1 20); do
      sleep 2
      [[ -z "$URL_ORDER" ]]     && URL_ORDER=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' /tmp/it-cf-order.log 2>/dev/null | head -1)
      [[ -z "$URL_INVENTORY" ]] && URL_INVENTORY=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' /tmp/it-cf-inventory.log 2>/dev/null | head -1)
      [[ -z "$URL_SHIPPING" ]]  && URL_SHIPPING=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' /tmp/it-cf-shipping.log 2>/dev/null | head -1)
      [[ -n "$URL_ORDER" && -n "$URL_INVENTORY" && -n "$URL_SHIPPING" ]] && break
    done
    ;;

  *)
    echo "Unknown TUNNEL_PROVIDER: $PROVIDER (use 'ngrok' or 'cloudflared')" >&2
    exit 1
    ;;
esac

: > "$URL_FILE"
{
  echo "order $URL_ORDER"
  echo "inventory $URL_INVENTORY"
  echo "shipping $URL_SHIPPING"
} >> "$URL_FILE"

echo ""
echo "========================================"
echo "Public tunnel URLs"
echo "========================================"
missing=0
for svc in order inventory shipping; do
  case "$svc" in
    order) url="$URL_ORDER"; port=$ORDER_PORT ;;
    inventory) url="$URL_INVENTORY"; port=$INVENTORY_PORT ;;
    shipping) url="$URL_SHIPPING"; port=$SHIPPING_PORT ;;
  esac
  if [[ -z "$url" ]]; then
    echo "  $svc (port $port): NO URL" >&2
    missing=1
  else
    printf "  %-10s :%s  %s\n" "$svc" "$port" "$url"
  fi
done
[[ "$missing" -ne 0 ]] && { echo "One or more tunnels failed." >&2; exit 1; }

echo ""
echo "URLs written to $URL_FILE"
echo ""
echo "Trigger the Harness CI pipeline 'integration_tests_hcli' and pass these as:"
echo "  ORDER_SERVICE_URL     = $URL_ORDER"
echo "  INVENTORY_SERVICE_URL = $URL_INVENTORY"
echo "  SHIPPING_SERVICE_URL  = $URL_SHIPPING"
echo ""
echo "Keep this terminal open while the pipeline runs. Ctrl-C to stop tunnels."

wait
