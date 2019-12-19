FROM alpine:latest

RUN apk --update add --no-cache ansible py3-pip openssh && \
    pip3 install --upgrade pip botocore boto3 && \
    mkdir -p /root/.ssh
WORKDIR /home
