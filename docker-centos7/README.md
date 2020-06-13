# Ansibleによる構成管理

## Dockerコンテナ

### 構成
```bash
./
|_ ansible/ # プロジェクトディレクトリ => docker://ansible:/ansible/ にマウントされる
|   |_ centos7-basic/ # CentOS7サーバの基本的な構成を構築するansible-playbook
|   |_ test/ # 動作確認用ansible-playbook
|
|_ docker/ # dockerコンテナビルド設定
|   |_ ansible/ # ansibleコンテナビルド設定
|   |    |_ Dockerfile
|   |
|   |_ centos/ # centosコンテナビルド設定
|        |_ Dockerfile
|_ docker-compose.yml # ansibleコンテナ: ansibleコマンド実行用環境
                      # centosコンテナ: ansibleで構成管理する対象の動作確認用サーバ
```

### 起動
```bash
$ export UID && docker-compose build
$ docker-compose up -d
```

***

## ansibleコンテナからcentosコンテナにSSH接続してみる

Ansibleを使う前に、SSH接続確認をしておく

```bash
# ansibleコンテナに入る
$ export UID && docker-compose exec ansible ash

# --- in ansible container ---
# centosコンテナにSSH接続
$ ssh root@centos

## => known_hosts に登録するため `yes` と打つ
## password: `root` と打つ

# --- in centos container by ssh ---
# 問題なく接続できたら exit
% exit
# --- /centos ---
```

***

## Ansibleを使ってみる

※ パスワード認証によるSSH接続の場合、先に `ssh` コマンドで接続して known_hosts 登録しておかないとうまく動作しない

※ 本稿の全ファイルは `./ansible/test/` ディレクトリ内にある

### インベントリファイルの作成
Ansibleの接続先サーバ情報等を記述した設定ファイルを**インベントリファイル**と呼ぶ

インベントリファイル名は任意だが、ここでは `servers.yml` というファイル名にする

なお、インベントリファイルの形式としては**ini形式**と**yaml形式**があるが、ここではyaml形式を採用する

`servers.yml` にサーバ情報を以下の通り記述する（yaml形式ではインデントにも意味があるため、インデント幅に注意すること）

```yaml
all:
  hosts: # ホスト定義
    docker: # docker host
      ansible_host: centos # 接続先サーバのIPアドレス or ドメイン名
      # vagrant host の SSH接続設定
      ansible_ssh_port: 22 # SSHのデフォルト接続ポートは 22番
      ansible_ssh_user: root # SSH接続ユーザ名
      ansible_sudo_pass: root # rootユーザパスワード
```

意味としては以下のようになる

- hosts設定:
    - 接続先サーバドメイン名 `centos`（`centos`Dockerコンテナ） を `docker` というエイリアス名に設定
- 各ホスト（エイリアス）ごとの設定: ここではSSH接続情報を記述
    - `ansible_ssh_port`: SSH接続ポート｜基本的に`22`を指定
    - `ansible_ssh_user`: SSH接続ユーザ
    - `ansible_ssh_pass`: SSH接続パスワード
        - パスワードをファイルに記述するのはセキュリティ的に問題があるため、本来は公開鍵認証にしたほうが良い（後述）
    - `ansible_sudo_pass`: rootユーザパスワード｜rootユーザでSSH接続する場合は `ansible_ssh_pass` と同一になる

### 単一コマンドの実行
インベントリファイルを作成したら、Ansibleでサーバ内のコマンドを実行させてみる

`servers.yml` があるディレクトリ内で以下のコマンドを実行

```bash
# --- in ansible container ---

# Ansibleでサーバ内に接続し hostname コマンドを実行
## ansible <エイリアス名>: エイリアス名に設定されたサーバに接続する
## -i <インベントリファイル>: インベントリファイルを指定
## -m <モジュール名>: Ansibleの実行モジュールを指定（ここでは command を指定）
## -a <引数>: Ansible実行モジュールの引数を指定
### => 今回は command モジュールのため `hostname -i` コマンドを実行するという意味になる
$ ansible docker -i servers.yml -m command -a "hostname -i" 

## => 172.21.0.2
### ここまでの設定が正しくできていれば上記のようなIPアドレスが返ってくるはず
```

### Playbookによるサーバ構成自動化
AnsibleにはPlaybookという、サーバ構成・状態を定義し、自動的に構成を行うことのできる仕組みがある

ここでは、サーバにユーザを新規作成し、SSH鍵を使ってSSH接続できるように構成する

Playbookファイルもyaml形式で記述し、ファイル名は任意だが、ここでは `playbook.yml` として以下のように記述する

```yaml
- hosts: docker # イベントリファイルに記述された docker ホスト（エイリアス）に対して実行
  become: true # sudo権限で実行
  tasks: # 各タスク定義｜nameは任意項目だが、分かりやすい名前をつけておくと管理しやすい
    - name: add a new user
      # Linuxユーザの作成
      ## userモジュール｜name=<ユーザ名> state=<present|absent> uid=<ユーザID>
      ### present: 存在する状態（存在しない場合は作成）, absent: 存在しない状態（存在する場合は削除）
      ### uidは指定しなくとも良いが、複数サーバでユーザIDを統一するためには指定しておく必要がある
      user: name=testuser state=present uid=1001

    - name: mkdir .ssh
      # .sshフォルダの作成
      ## fileモジュール｜path=<ファイルパス> state=<file|directory|...> owner=<所有者> group=<所有グループ> mode=<パーミッション>
      ### パーミッションは8進数で指定しなければならないため 0700 や '700' などのように指定すること
      file: path=/home/testuser/.ssh/ state=directory owner=testuser group=testuser mode=0700

    - name: generate ssh key
      # SSH鍵ペアの生成
      ## userモジュール｜generate_ssh_key=yes: SSH鍵ペアを生成
      ### => /home/testuser/.ssh/ に id_rsa（秘密鍵）, id_rsa.pub（公開鍵）生成
      user: name=testuser generate_ssh_key=yes
    
    - name: ssh key authentication
      # 公開鍵をSSH認証鍵として登録
      ## copyモジュール｜src=<コピー元パス> dest=<コピー先パス> remote_src=<no|yes>
      ### remote_src=yes にするとリモートホスト内でファイルコピーを実行（remote_src=no ならアップロード処理に近い挙動）
      ### /home/testuser/.ssh/id_rsa.pub => authorized_keys に変更
      copy: src=/home/testuser/.ssh/id_rsa.pub dest=/home/testuser/.ssh/authorized_keys owner=testuser group=testuser mode=0600 remote_src=yes

    - name: download ssh-key
      # SSH鍵のダウンロード
      ## fetchモジュール｜src=<サーバ内のファイルパス> dest=<ローカルの保存先パス> flat=<no|yes>
      ### flat=noだと、srcで指定したパスをまるごと保存してしまうため、yesを指定してファイル名のみでファイルを保存するようにする
      fetch: src=/home/testuser/.ssh/id_rsa dest=~/.ssh/testuser-id_rsa flat=yes
```

各タスクの内容は、コメントの通りである

playbook.yml が作成できたら、以下のコマンドでPlaybookを実行

```bash
# --- in ansible container ---

# ansible-playbook -i <インベントリファイル> <Playbookファイル>
$ ansible-playbook -i servers.yml playbook.yml
    :
docker  : ok=6  changed=6  unreachable=0  failed=0  skipped=0  rescued=0  ignored=0
```

実行すると、`testuser`ユーザが作成され、そのユーザでログインするためのSSH秘密鍵が `./ssh/testuser-id_rsa` に保存されるはず

なお、もう一度Playbookを実行すると `changed=0` となり、最終的なサーバ構成・状態は同一になることが担保されている（**べき等性**）

```bash
# もう一度Playbookを実行した場合
$ ansible-playbook -i servers.yml playbook.yml
    :
## => changed=0 となり、現在のサーバの状態に合わせて何の変更も加えなかったことが分かる
docker  : ok=6  changed=0  unreachable=0  failed=0  skipped=0  rescued=0  ignored=0
```

### 複数のSSH接続ユーザ設定
ここまで設定すると `testuser` ユーザでもSSH接続できるようになる

まずは普通に `ssh`コマンドで接続してみる

```bash
# --- in ansible container ---

# Ansibleにより生成＆ダウンロードされたSSH秘密鍵のパーミッションを変更
$ chmod 600 ~/.ssh/testuser-id_rsa

# testuserユーザで centosコンテナにSSH接続
## known_hosts に登録せずにSSH接続確認したい場合は
## $ ssh -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no -i ./ssh/testuser-id_rsa testuser@centos
$ ssh -i ~/.ssh/testuser-id_rsa testuser@centos

# --- in centos container by ssh ---
# SSH接続できることを確認したらそのまま exit
[testuser ~]$ exit
```

続いてインベントリファイル `servers.yml` に `testuser`ユーザでのSSH接続設定を追加する

公開鍵で認証する場合は、`ansible_ssh_private_key_file` 設定で鍵ファイルを指定する

```yaml
all:
  hosts: # ホスト定義
    docker: # docker host
      ansible_host: centos # 接続先サーバのIPアドレス or ドメイン名
      # vagrant host の SSH接続設定
      ansible_ssh_port: 22 # SSHのデフォルト接続ポートは 22番
      ansible_ssh_user: root # SSH接続ユーザ名
      ansible_ssh_pass: root # SSH接続パスワード
      ansible_sudo_pass: root # rootユーザパスワード
    test: # test host
      ansible_host: centos
      # test host の SSH接続設定
      ansible_ssh_port: 22
      ansible_ssh_user: testuser # testuserで接続
      # SSH秘密鍵
      ansible_ssh_private_key_file: ~/.ssh/testuser-id_rsa
      ansible_sudo_pass: root
```

`testuser`ユーザで接続するための `test`ホストの設定を用いてAnsibleコマンドを実行してみる

```bash
# ansible command by `test` host
## whoami コマンドをサーバ内で実行
$ ansible test -i servers.yml -m command -a "whoami"

## => testuser
### ログインユーザ名が返ってきたら成功
```

基本的な使い方は以上である

その他、Ansibleで使用できるモジュールなどは[公式ページ](https://docs.ansible.com/ansible/latest/modules/modules_by_category.html)を参照すると良い
