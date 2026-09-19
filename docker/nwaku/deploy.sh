#!/bin/sh
# NexusChat 自建 Waku 中继节点部署脚本
# 镜像: wakuorg/nwaku:v0.38.1
#
# 关键修复（解决节点无 peers → Relay/FILTER 一直 NOT_READY）：
#   1. --nat=nay 改为 --nat=extip:$EXT_ADDRESS，否则节点不对外宣告可达地址，
#      其它节点无法连入，导致 Relay/FILTER 一直 NOT_READY、No connected peers。
#      （这就是之前 /relay/v1/auto/* 与 /filter/v2/* 返回 404 的真正原因——
#        不是 REST handler 没挂载，而是 Relay 协议未就绪；store 能 200 是因为
#       store 是本地协议、不需要 peers。）
#   2. 增加 --discv5-udp-port=9000，与已发布的 9000:9000/udp 对应，
#      否则 discv5 默认用 TCP 端口做 UDP，而该 UDP 端口未发布，发现不到对等节点。
#   3. 额外发布 $TCP_PORT:$TCP_PORT/udp，便于 libp2p QUIC/通用 UDP 连通。
#
# ⚠️ REST flag 说明（v0.38.1 实测）：
#   --rest=true 已经挂载全部 REST 子接口（relay/filter/lightpush/store），
#   不要再写 --rest-relay / --rest-filter / --rest-lightpush / --rest-store，
#   这些 flag 在本版本不存在，会直接导致容器启动失败：
#   "Unrecognized option 'rest-relay'"。
#   保留 --rest=true 即可。
#
# 注意（反向代理层）：若 /relay/v1/auto/messages/... 仍 404 且响应体是被解码后的
# topic 路径（如 /nexuschat/1/...），是 1Panel/OpenResty 把 %2F 提前解码成 /
# 再转发导致的。反代配置需用：proxy_pass http://127.0.0.1:8645$request_uri;
# 避免 rewrite 改变路径；必要时加 merge_slashes off;

docker rm -f nwaku
#docker volume rm nwaku-data

# 1. 检测并生成永久节点密钥
if [ -z "$NWAKU_NODEKEY" ]; then
  NWAKU_NODEKEY=$(openssl rand -hex 32)
  echo "export NWAKU_NODEKEY=$NWAKU_NODEKEY" >> ~/.bashrc
  . ~/.bashrc
  echo "✅ 已生成并写入永久节点密钥: $NWAKU_NODEKEY"
else
  echo "ℹ️ 使用已有永久密钥: $NWAKU_NODEKEY"
fi

# 2. 基础配置
export TCP_PORT=60000
export EXT_ADDRESS=212.192.15.218
export STATIC_NODES="/ip4/212.192.15.218/tcp/60000/p2p/16Uiu2HAmHmS5FL7VyiPwSFoWWTALVeFkzox3JjUkbcaVzDiq9Bw2,/ip4/47.238.90.232/tcp/50000/p2p/16Uiu2HAkucpnza7D7CzpmqstqxkZveLnbhVM5bASugyzD53kFLcG"

# 3. 自动过滤自身节点，拼接 staticnode 参数
STATIC_ARGS=""
OLD_IFS=$IFS
IFS=','
for node in $STATIC_NODES; do
  node_ip=$(echo "$node" | awk -F'/' '{print $3}')
  if [ "$node_ip" != "$EXT_ADDRESS" ]; then
    STATIC_ARGS="$STATIC_ARGS --staticnode=$node"
  fi
done
IFS=$OLD_IFS
node_count=$(echo "$STATIC_ARGS" | grep -c "\-\-staticnode" 2>/dev/null || echo 0)
echo "ℹ️ 已排除自身节点，最终静态节点数量: $node_count"

# 4. 启动容器
docker run -d \
  --name nwaku \
  --restart unless-stopped \
  -p $TCP_PORT:$TCP_PORT \
  -p $TCP_PORT:$TCP_PORT/udp \
  -p 9000:9000/udp \
  -p 8645:8645 \
  -p 8000:8000 \
  -v $(pwd)/nwaku-data:/app \
  wakuorg/nwaku:v0.38.1 \
  --nodekey=$NWAKU_NODEKEY \
  --tcp-port=$TCP_PORT \
  --cluster-id=10000 \
  --peer-exchange=true \
  --lightpush=true \
  --filter=true \
  --relay=true \
  --discv5-discovery=true \
  --discv5-udp-port=9000 \
  $STATIC_ARGS \
  --rest=true \
  --rest-address=0.0.0.0 \
  --rest-allow-origin="*" \
  --rest-relay-cache-capacity=5000 \
  --rest-admin=true \
  --rest-port=8645 \
  --nat=extip:$EXT_ADDRESS \
  --store=true \
  --store-message-retention-policy=size:5000MB \
  --store-message-db-vacuum=true \
  --websocket-support=true \
  --websocket-port=8000
