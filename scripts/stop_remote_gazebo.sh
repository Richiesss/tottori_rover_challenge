#!/usr/bin/env bash
# start_remote_gazebo.sh で起動したx11vncを止め、コンテナも終了する
set -euo pipefail

cd "$(dirname "$0")/.."

VNC_PORT="${VNC_PORT:-5900}"

echo "==> x11vnc (port $VNC_PORT) を停止"
pkill -f "x11vnc .*-rfbport $VNC_PORT" 2>/dev/null || true

echo "==> docker compose down"
docker compose down
