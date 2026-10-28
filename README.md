# ROS 2 Jazzy + TurtleBot3 Docker環境

ROS 2 Jazzy / Gazebo Sim (Harmonic) / TurtleBot3 を全員同じ環境で動かすためのDocker構成です。

## 必要なもの

| ホスト | 必要なもの |
| --- | --- |
| Windows 11 + WSL2 (Ubuntu 24.04) | WSL内にDocker Engine（またはDocker DesktopのWSL連携）。GUIはWSLgで表示 |
| ネイティブUbuntu 24.04 | Docker Engine |

`docker` を `sudo` なしで実行できるようにしておいてください（`sudo usermod -aG docker $USER` → 再ログイン）。

## 初回セットアップ

```bash
git clone <このリポジトリ> ros2_tb3_docker
cd ros2_tb3_docker

cp .env.example .env
# .env を開いて COMPOSE_FILE を自分の環境（WSL2 / ネイティブUbuntu）に合わせる
# USER_UID / USER_GID を `id -u` / `id -g` の値にする

# ネイティブUbuntuのみ: コンテナからXサーバに描画できるようにする（ログインごとに必要）
xhost +local:

docker compose build      # 初回は10分ほどかかる
```

## 使い方

```bash
docker compose up -d                 # コンテナ起動（バックグラウンド）
docker compose exec ros bash         # コンテナに入る。ターミナルを増やすときも同じコマンド

# --- コンテナ内 ---
ros2 launch turtlebot3_gazebo turtlebot3_world.launch.py
# 別ターミナル（docker compose exec ros bash）で
ros2 run turtlebot3_teleop teleop_keyboard
```

```bash
docker compose down                  # 終了
```

## ディレクトリ構成

```
.
├── Dockerfile            # イメージ定義（ROS 2 Jazzy desktop + TurtleBot3一式）
├── compose.yaml          # 共通設定
├── compose.wsl.yaml      # WSL2 (WSLg) 用の追加設定
├── compose.linux.yaml    # ネイティブUbuntu用の追加設定
├── compose.software-render.yaml  # GPU初期化に失敗する場合のソフトウェアレンダリング用オーバーレイ
├── .env.example          # 各自の .env の雛形（.env はコミットしない）
└── ws/                   # colconワークスペース。コンテナ内の ~/ws にマウントされる
    └── src/              # 自作パッケージはここに置く
```

`ws/` はホストと共有されているので、ホスト側のVS Codeで編集してコンテナ内で `colcon build` できます。
`ws/install/setup.bash` は、ビルド済みならコンテナに入ったときに自動で読み込まれます。

```bash
# コンテナ内
cd ~/ws
colcon build --symlink-install
source install/setup.bash
```

## リモート環境（別マシン）からGUIを見る（VNC経由）

VS CodeのRemote-SSHなどでこのWSL環境に接続している場合、WSLgの画面はWindows側にしか表示されません。
別マシン（例: MacBook）でGazeboのウィンドウを見たい場合は、`x11vnc` でWSLgの画面を共有し、
VS CodeのポートフォワードでクライアントPCまで中継します。

```bash
# WSL側: 初回のみ
sudo apt-get update && sudo apt-get install -y x11vnc
mkdir -p ~/.vnc
x11vnc -storepasswd ~/.vnc/passwd     # VNC用パスワードを設定

# Gazeboなどを起動した後、別ターミナルで実行
env -u WAYLAND_DISPLAY x11vnc -display :0 -rfbauth ~/.vnc/passwd \
    -localhost -forever -shared -noxdamage -noshm -id pick -rfbport 5900
# 「クリックでウィンドウを選択してください」と出るので、
# WSLg側に表示されているGazeboなどのウィンドウをクリックする
```

- WSLgはXWayland上でウィンドウ単位に合成しているため、デスクトップ全体ではなく
  `-id pick` で個別のウィンドウを選んで共有する必要がある（デスクトップ全体を掴もうとすると
  `BadMatch`エラーになる）。
- `-localhost` でVNCサーバーをWSL内のループバックのみに公開し、外部には直接公開しない。

次にクライアント側（VS Codeを動かしているPC）で：

1. VS Codeの **PORTS** タブ → **Add Port** → `5900` を追加（Remote-SSH越しでも自動的にクライアントPCまでトンネルされる）
2. VNCクライアントで `vnc://localhost:5900` に接続し、上で設定したパスワードを入力
   （Macなら Finder → 移動（⌘K）→ `vnc://localhost:5900` で標準の「画面共有」が使える）

## パッケージを追加したいとき

`Dockerfile` の `apt-get install` に追記して `docker compose build` し直し、変更をコミットしてください。
コンテナ内で `sudo apt install` したものは、コンテナを作り直すと消え、他の人にも共有されません。

## トラブルシューティング

- **GUIが出ない（ネイティブUbuntu）**: ホストで `xhost +local:` を実行したか確認。
- **GUIが出ない（WSL2）**: `.env` の `COMPOSE_FILE` が `compose.wsl.yaml` を含んでいるか確認。`wsl --shutdown` 後に再度試す。
- **Gazeboが真っ黒 / すぐ落ちる（`libEGL warning: failed to open /dev/dri/renderD128: Permission denied`）**: ホストの`render`グループGIDとコンテナ内のGIDが一致していません。ホストで `getent group render` を実行し、出てきたGIDを `.env` の `RENDER_GID` に設定して `docker compose up -d --force-recreate` し直してください。
- **Gazeboが真っ黒 / すぐ落ちる（GPU権限は問題ないのにOpenGLコンテキスト生成に失敗する/セグフォルトする）**: WSLgのD3D12/EGL初期化自体が失敗している場合があります。`.env` の `COMPOSE_FILE` に `compose.software-render.yaml` を追加し、`LIBGL_ALWAYS_SOFTWARE=1` と `GALLIUM_DRIVER=llvmpipe` を設定してソフトウェアレンダリングに切り替えてください（`GALLIUM_DRIVER=d3d12` のまま `LIBGL_ALWAYS_SOFTWARE=1` だけ設定すると `Not allowed to force software rendering when API explicitly selects a hardware device` でクラッシュします）。
- **`docker compose build` が `error getting credentials` で失敗する（WSL2）**: Docker DesktopやWindows側の認証情報ヘルパーとの連携が切れています。ベースイメージは公開イメージなので、空の設定を使えばビルドできます。
  ```bash
  mkdir -p /tmp/empty-docker-config
  DOCKER_CONFIG=/tmp/empty-docker-config docker compose build
  ```
- **他の人のロボットのトピックが見える**: 同じLAN内では通信が混ざります。`.env` の `ROS_DOMAIN_ID` を人ごとに変えてください。
- **`ws/` のファイルがrootの所有になる**: `.env` の `USER_UID` / `USER_GID` がホストと一致しているか確認し、`docker compose build` し直す。
