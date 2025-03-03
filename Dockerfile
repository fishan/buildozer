# Dockerfile для сборки Buildozer на aarch64
# Сборка через GitHub Actions:
# docker buildx build --platform=linux/arm64 -t ghcr.io/твой_юзер/buildozer:latest .
#
# Запуск на планшете:
# docker run --rm \
#   -v "$PWD":/home/user/hostcwd \
#   ghcr.io/твой_юзер/buildozer:latest android debug

FROM ubuntu:22.04

ENV USER="user" \
    HOME_DIR="/home/user" \
    WORK_DIR="/home/user/hostcwd" \
    ANDROID_HOME="/home/user/android-sdk" \
    NDK_HOME="/home/user/android-ndk" \
    PATH="/home/user/.local/bin:/home/user/android-sdk/cmdline-tools/latest/bin:/home/user/android-ndk:$PATH"

# Настройка локалей
RUN apt update -qq > /dev/null \
    && DEBIAN_FRONTEND=noninteractive apt install -qq --yes --no-install-recommends \
    locales \
    && locale-gen en_US.UTF-8
ENV LANG="en_US.UTF-8" \
    LANGUAGE="en_US.UTF-8" \
    LC_ALL="en_US.UTF-8"

# Установка системных зависимостей
RUN apt update || { echo "apt update failed"; exit 1; }
RUN DEBIAN_FRONTEND=noninteractive apt install --yes --no-install-recommends \
    autoconf automake build-essential ccache cmake curl git \
    libffi-dev libssl-dev libtool openjdk-17-jdk patch \
    python3-pip python3-setuptools unzip zip zlib1g-dev \
    2>&1 | tee /tmp/apt-install.log || { echo "apt install failed with details:"; cat /tmp/apt-install.log; exit 1; }

# Создание пользователя
RUN useradd --create-home --shell /bin/bash ${USER} \
    && chown -R ${USER}:${USER} ${HOME_DIR}

USER ${USER}
WORKDIR ${HOME_DIR}

# Установка Android SDK
RUN curl -o sdk-tools.zip https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip || { echo "curl failed to download SDK tools"; exit 1; }
RUN unzip sdk-tools.zip -d ${ANDROID_HOME}/cmdline-tools || { echo "unzip failed"; ls -la ${ANDROID_HOME}; exit 1; }
RUN rm sdk-tools.zip || { echo "rm sdk-tools.zip failed"; exit 1; }
RUN mkdir -p ${ANDROID_HOME}/cmdline-tools/latest || { echo "mkdir cmdline-tools/latest failed"; exit 1; }
RUN mv ${ANDROID_HOME}/cmdline-tools/cmdline-tools/* ${ANDROID_HOME}/cmdline-tools/latest/ || { echo "mv cmdline-tools failed"; ls -la ${ANDROID_HOME}; ls -la ${ANDROID_HOME}/cmdline-tools; ls -la ${ANDROID_HOME}/cmdline-tools/cmdline-tools; exit 1; }
RUN yes | ${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager --licenses || { echo "sdkmanager licenses failed"; exit 1; }
RUN ${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager --install "platforms;android-33" "build-tools;33.0.0" "platform-tools" || { echo "sdkmanager install failed"; exit 1; }

# Установка Android NDK
RUN curl -o ndk.zip https://dl.google.com/android/repository/android-ndk-r25c-linux.zip || { echo "curl failed to download NDK"; exit 1; }
RUN unzip ndk.zip -d ${HOME_DIR} || { echo "unzip NDK failed"; ls -la; exit 1; }
RUN mv android-ndk-r25c ${NDK_HOME} || { echo "mv NDK failed"; ls -la ${HOME_DIR}; exit 1; }
RUN rm ndk.zip || { echo "rm ndk.zip failed"; exit 1; }

# Установка Buildozer
RUN pip3 install --user --upgrade "Cython<3.0" wheel pip buildozer

WORKDIR ${WORK_DIR}
ENTRYPOINT ["buildozer"]
CMD ["android", "debug"]
