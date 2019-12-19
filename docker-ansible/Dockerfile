FROM alpine:latest

RUN : '必要なパッケージのインストール' && \
    apk --update add --no-cache ansible py3-pip openssh sshpass && \
    pip3 install --upgrade pip botocore boto3 && \
    : '作業ディレクトリ作成' && \
    mkdir /ansible

# 作業ディレクトリ
WORKDIR /ansible
