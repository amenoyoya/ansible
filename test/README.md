# Ansible 動作検証

## Dockerコンテナ

### 構成
```bash
./
|_ centos/ # centosコンテナビルド設定
|   |_ Dockerfile
|_ docker-compose.yml # centosコンテナ: ansibleで構成管理する対象の動作確認用サーバ
                      ## port 8022 => docker://caneos:22
```

### 起動
```bash
$ docker-compose build
$ docker-compose up -d
```

***

## centosコンテナにSSH接続してみる

Ansibleを使う前に、SSH接続確認をしておく

```bash
# centosコンテナにSSH接続
## port 8022 => docker://centos:22 にポーティングされているため port 8022 から接続する
$ ssh -p 8022 root@localhost

## => known_hosts に登録するため `yes` と打つ
## password: `root` と打つ

# -- root@docker.centos
# 問題なく接続できたら exit
% exit
```
