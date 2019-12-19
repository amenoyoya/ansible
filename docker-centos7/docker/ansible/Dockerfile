FROM alpine:latest

# Docker実行ユーザID取得
ARG UID

RUN : '必要なパッケージのインストール' && \
    apk --update add --no-cache ansible py3-pip openssh sshpass && \
    pip3 install --upgrade pip botocore boto3 && \
    : 'alpineユーザ追加（ユーザIDをDocker実行ユーザIDと合わせる）' && \
    adduser -u $UID -h /home/alpine -S alpine && \
    : 'alpineユーザをsudoersに追加' && \
    echo 'alpine ALL=(ALL) NOPASSWORD:ALL' >> /etc/sudoers && \
    : 'alpineユーザのパスワードを`alpine`に変更' && \
    echo 'alpine:alpine' | chpasswd && \
    : 'プロジェクトディレクトリ作成' && \
    mkdir /ansible

# 実行ユーザ, プロジェクトディレクトリ
USER alpine
WORKDIR /ansible
