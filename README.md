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

## パッケージを追加したいとき

`Dockerfile` の `apt-get install` に追記して `docker compose build` し直し、変更をコミットしてください。
コンテナ内で `sudo apt install` したものは、コンテナを作り直すと消え、他の人にも共有されません。

## トラブルシューティング

- **GUIが出ない（ネイティブUbuntu）**: ホストで `xhost +local:` を実行したか確認。
- **GUIが出ない（WSL2）**: `.env` の `COMPOSE_FILE` が `compose.wsl.yaml` を含んでいるか確認。`wsl --shutdown` 後に再度試す。
- **Gazeboが真っ黒 / すぐ落ちる**: GPUまわりの問題のことが多いです。`.env` に `LIBGL_ALWAYS_SOFTWARE=1` を書いて `docker compose up -d` し直し、ソフトウェアレンダリングを試してください。
- **`docker compose build` が `error getting credentials` で失敗する（WSL2）**: Docker DesktopやWindows側の認証情報ヘルパーとの連携が切れています。ベースイメージは公開イメージなので、空の設定を使えばビルドできます。
  ```bash
  mkdir -p /tmp/empty-docker-config
  DOCKER_CONFIG=/tmp/empty-docker-config docker compose build
  ```
- **他の人のロボットのトピックが見える**: 同じLAN内では通信が混ざります。`.env` の `ROS_DOMAIN_ID` を人ごとに変えてください。
- **`ws/` のファイルがrootの所有になる**: `.env` の `USER_UID` / `USER_GID` がホストと一致しているか確認し、`docker compose build` し直す。
