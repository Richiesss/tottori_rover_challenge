#!/usr/bin/env bash
# docker compose起動 → コンテナ内でGazebo起動 → そのウィンドウをVNCで共有する
# までを1コマンドでまとめて行う（WSLg + x11vnc + VS Codeポートフォワード経由で
# リモートPCからGUIを見る用途）。
#
# 使い方:
#   ./scripts/start_remote_gazebo.sh
#   ./scripts/start_remote_gazebo.sh "ros2 launch turtlebot3_gazebo turtlebot3_house.launch.py"
#
# 前提: WSL側に x11vnc と xdotool がインストール済みであること
#   sudo apt-get install -y x11vnc xdotool
set -euo pipefail

cd "$(dirname "$0")/.."

LAUNCH_CMD="${1:-ros2 launch turtlebot3_gazebo turtlebot3_world.launch.py}"
WINDOW_NAME_PATTERN="${WINDOW_NAME_PATTERN:-[Gg]azebo}"
VNC_PORT="${VNC_PORT:-5900}"
VNC_PASSWD_FILE="${VNC_PASSWD_FILE:-$HOME/.vnc/passwd}"
CONTAINER_LOG="/tmp/gazebo_launch.log"

for cmd in x11vnc xdotool; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "エラー: $cmd がインストールされていません。" >&2
    echo "  sudo apt-get install -y x11vnc xdotool" >&2
    exit 1
  fi
done

if [ ! -f "$VNC_PASSWD_FILE" ]; then
  echo "==> 初回起動: VNCパスワードを設定します"
  mkdir -p "$(dirname "$VNC_PASSWD_FILE")"
  x11vnc -storepasswd "$VNC_PASSWD_FILE"
fi

echo "==> docker compose up"
docker compose up -d

echo "==> コンテナ内でGazeboを起動: $LAUNCH_CMD"
# bash -lc は .bashrc を読まないのでROSの環境が入らない。setup.bashを直接sourceする。
docker compose exec -d ros bash -c "
  source /opt/ros/jazzy/setup.bash
  [ -f ~/ws/install/setup.bash ] && source ~/ws/install/setup.bash
  $LAUNCH_CMD > $CONTAINER_LOG 2>&1
"

echo "==> Gazeboのウィンドウが出るまで待機"
# 同名で幅1x1などのダミーウィンドウが混在することがあるため、
# 最も面積の大きいウィンドウを選ぶ（最小サイズも満たすことを確認）
MIN_WIDTH=200
MIN_HEIGHT=200
WIN_ID=""
for _ in $(seq 1 60); do
  BEST_AREA=0
  for id in $(DISPLAY=:0 xdotool search --name "$WINDOW_NAME_PATTERN" 2>/dev/null); do
    geom=$(DISPLAY=:0 xdotool getwindowgeometry --shell "$id" 2>/dev/null) || continue
    width=$(echo "$geom" | sed -n 's/^WIDTH=//p')
    height=$(echo "$geom" | sed -n 's/^HEIGHT=//p')
    [ -z "$width" ] || [ -z "$height" ] && continue
    if [ "$width" -ge "$MIN_WIDTH" ] && [ "$height" -ge "$MIN_HEIGHT" ]; then
      area=$((width * height))
      if [ "$area" -gt "$BEST_AREA" ]; then
        BEST_AREA=$area
        WIN_ID=$id
      fi
    fi
  done
  if [ -n "$WIN_ID" ]; then
    break
  fi
  sleep 1
done

if [ -z "$WIN_ID" ]; then
  echo "エラー: Gazeboのウィンドウが見つかりませんでした。" >&2
  echo "  docker compose exec ros cat $CONTAINER_LOG  でエラーを確認してください。" >&2
  echo "  見つかっているが名前が違う場合は WINDOW_NAME_PATTERN を指定してやり直してください。" >&2
  exit 1
fi

echo "==> ウィンドウID $WIN_ID を VNC (port $VNC_PORT) で共有します"
pkill -f "x11vnc .*-rfbport $VNC_PORT" 2>/dev/null || true

env -u WAYLAND_DISPLAY x11vnc -display :0 -rfbauth "$VNC_PASSWD_FILE" \
    -localhost -forever -shared -noxdamage -noshm \
    -id "$WIN_ID" -rfbport "$VNC_PORT" -bg

echo "==> 完了"
echo "    VS CodeのPORTSタブで ${VNC_PORT} を追加し、"
echo "    クライアント側から vnc://localhost:${VNC_PORT} で接続してください。"
echo "==> コンテナのROS 2環境に入ります（teleopなど追加のコマンドはここで）"
exec docker compose exec ros bash
