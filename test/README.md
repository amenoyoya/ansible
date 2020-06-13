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

## 動作確認

### cenosコンテナにSSH接続
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

### Ansible で centosコンテナでコマンド実行
```bash
# ansibleインベントリファイルに接続先ホスト情報記述
## /etc/ansible/hosts がデフォルトのインベントリファイル
## 任意のファイルに記述して ansible(-playbook) の -i オプションで読み込んでも良い
$ sudo tee -a /etc/ansible/hosts << EOS
[docker-centos7]
localhost:8022
EOS

# インベントリファイルに記述したホスト（docker-centos7）で Ansible 実行
# ansible <ホスト名> [オプション: 以下参照]
## -u <ユーザ名>: SSH接続ユーザ
## --ask-pass: SSH接続がパスワード認証の時指定
## -m <実行モジュール>: 実行する Ansible モジュール（今回は command 実行）
## -a <実行モジュール引数>: 今回は hostname コマンドを実行
$ ansible docker-centos7 -u root --ask-pass -m command -a hostname
SSH password: # <= root
localhost | CHANGED | rc=0 >>
0df3b13f8dda # => hostname コマンドの実行結果
```
