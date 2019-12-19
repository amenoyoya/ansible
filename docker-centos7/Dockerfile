FROM centos:7

# rootユーザパスワード
ARG ROOT_PASSWORD=root

# rootログインできるssh-server用意
RUN yum -y install initscripts MAKEDEV && \
    yum check && \
    yum -y update && \
    yum -y install openssh-server && \
    : 'rootユーザパスワード変更' && \
    echo "root:$ROOT_PASSWORD" | chpasswd && \
    : 'sshd有効化' && \
    systemctl enable sshd.service

EXPOSE 22
