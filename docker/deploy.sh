#!/usr/bin/env bash
# NexusChat Waku 節點部署腳本
# 兩個 nwaku 節點以固定 IP + staticnode 互相直連，不依賴外部 fleet。
set -euo pipefail

DIR=/opt/nexuschat/nwaku
cd "$DIR"

# shellcheck disable=SC1091
set -a; . ./.env; set +a
A_URL="http://127.0.0.1:${REST_A_PORT:-8645}"
B_URL="http://127.0.0.1:${REST_B_PORT:-8646}"

peer_of() { # $1 = base url
  local i info p
  for i in $(seq 1 45); do
    info=$(curl -sf --max-time 3 "$1/debug/v1/info" 2>/dev/null || true)
    if [ -n "$info" ]; then
      p=$(printf '%s' "$info" | grep -oE 'p2p/[A-Za-z0-9]+' | head -1 | cut -d/ -f2)
      if [ -n "$p" ]; then printf '%s' "$p"; return 0; fi
    fi
    sleep 2
  done
  return 1
}

relay_ready() { curl -sf --max-time 3 "$1/health" 2>/dev/null | grep -q '"Relay":"READY"'; }

set_env() { # $1=key $2=val
  touch .env
  grep -v "^$1=" .env > .env.tmp 2>/dev/null || true
  echo "$1=$2" >> .env.tmp
  mv .env.tmp .env
}

# 1. 清掉舊的單節點容器（佔用 8645）
if docker ps -a --format '{{.Names}}' | grep -qx 'nwaku'; then
  echo ">> 移除舊的單節點容器 nwaku"
  docker rm -f nwaku >/dev/null 2>&1 || true
fi

# 2. 啟動兩個節點
echo ">> 啟動 nwaku-a / nwaku-b"
docker compose up -d

A_PEER=$(peer_of "$A_URL") || { echo "!! 取不到 nwaku-a peer id" >&2; exit 1; }
B_PEER=$(peer_of "$B_URL") || { echo "!! 取不到 nwaku-b peer id" >&2; exit 1; }
echo ">> A peer = $A_PEER"
echo ">> B peer = $B_PEER"

# 3. peer id 與 .env 不符時（例如換過私鑰）重新產生容器
CHANGED=0
[ "$A_PEER" != "${NWAKU_A_PEER:-}" ] && { set_env NWAKU_A_PEER "$A_PEER"; CHANGED=1; }
[ "$B_PEER" != "${NWAKU_B_PEER:-}" ] && { set_env NWAKU_B_PEER "$B_PEER"; CHANGED=1; }
if [ "$CHANGED" = "1" ]; then
  echo ">> peer id 有變動，重建容器"
  docker compose up -d
  sleep 5
fi

# 4. 等待互相連線
echo ">> 等待兩節點建立連線..."
OK=0
for _ in $(seq 1 40); do
  if relay_ready "$A_URL" && relay_ready "$B_URL"; then OK=1; break; fi
  sleep 3
done

if [ "$OK" != "1" ]; then
  echo "!! 兩節點未連線，nwaku-b 最近日誌：" >&2
  docker compose logs --tail 25 nwaku-b >&2
  exit 1
fi
echo ">> 兩節點已互連（兩邊 Relay 皆 READY）"

# 5. 摘要
for P in "${REST_A_PORT:-8645}" "${REST_B_PORT:-8646}"; do
  printf '%s\n' "--- :$P ---"
  curl -s --max-time 5 "http://127.0.0.1:$P/health" | head -c 200
  echo
done
echo "== 部署完成 =="
