# ROS 2 Jazzy + TurtleBot3 (Gazebo Sim Harmonic) 開発環境
FROM osrf/ros:jazzy-desktop

ARG USERNAME=ros
ARG USER_UID=1000
ARG USER_GID=${USER_UID}

ENV DEBIAN_FRONTEND=noninteractive

# TurtleBot3関連パッケージ（Gazebo Simは依存として入る）と開発ツール
RUN apt-get update && apt-get install -y --no-install-recommends \
        ros-jazzy-turtlebot3-simulations \
        ros-jazzy-turtlebot3-teleop \
        ros-jazzy-turtlebot3-cartographer \
        ros-jazzy-turtlebot3-navigation2 \
        ros-jazzy-mouse-teleop \
        python3-colcon-common-extensions \
        python3-colcon-clean \
        python3-rosdep \
        python3-vcstool \
        python3-argcomplete \
        bash-completion \
        sudo \
        git \
        vim \
        less \
        mesa-utils \
        x11-apps \
    && rm -rf /var/lib/apt/lists/*

# ホストと同じUID/GIDの一般ユーザーを作る（マウントしたファイルの所有者がずれないように）
# ubuntu:24.04系イメージには UID 1000 の "ubuntu" ユーザーが既にいるので、その場合は名前を変える
RUN set -eux; \
    if getent group "${USER_GID}" >/dev/null; then \
        groupmod -n "${USERNAME}" "$(getent group "${USER_GID}" | cut -d: -f1)"; \
    else \
        groupadd -g "${USER_GID}" "${USERNAME}"; \
    fi; \
    if getent passwd "${USER_UID}" >/dev/null; then \
        usermod -l "${USERNAME}" -d "/home/${USERNAME}" -m -g "${USER_GID}" -s /bin/bash \
            "$(getent passwd "${USER_UID}" | cut -d: -f1)"; \
    else \
        useradd -m -s /bin/bash -u "${USER_UID}" -g "${USER_GID}" "${USERNAME}"; \
    fi; \
    usermod -aG video,render "${USERNAME}" || true; \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${USERNAME}"; \
    chmod 0440 "/etc/sudoers.d/${USERNAME}"

ENV TURTLEBOT3_MODEL=burger

USER ${USERNAME}
WORKDIR /home/${USERNAME}/ws

RUN rosdep update --rosdistro jazzy \
    && { \
        echo ''; \
        echo '# --- ROS 2 ---'; \
        echo 'source /opt/ros/jazzy/setup.bash'; \
        echo '[ -f ~/ws/install/setup.bash ] && source ~/ws/install/setup.bash'; \
        echo 'export TURTLEBOT3_MODEL=${TURTLEBOT3_MODEL:-burger}'; \
    } >> "/home/${USERNAME}/.bashrc"

CMD ["bash"]
