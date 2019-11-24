# サーバ構成のテンプレート化

仕事では CentOS 6, 7系のVPSを使うことが多いため、ここでは CentOS 7 を基本としてテンプレートを作成している

## 共通セキュリティ設定

参考: [そこそこセキュアなlinuxサーバーを作る](https://qiita.com/cocuh/items/e7c305ccffb6841d109c)

とりあえず行わなければならない基本的なセキュリティ設定は以下の通り

1. **sshd**（SSH接続関連）
    - **ポート変更**
        - SSHのデフォルト接続ポート25番は一般に知れ渡っており標的の対象となりやすいため、別のポートに変更する
    - **rootログイン不可**
        - rootはすべてのサーバにあるユーザであるため総当り攻撃される危険性がある
        - root権限はサーバ内のあらゆる操作が可能であるため乗っ取られると非常に危険
    - **パスワード認証不可**
        - パスワード認証は総当り攻撃の対象になるため禁止する（公開鍵認証のみ許可とする）
    - **SSH接続できないユーザの作成**
        - Web制作をしていると、デザイナやコーダーなどがFTP（SFTP）でファイルアップロードしたいという要望がある
        - そのような場合のために、SSH接続不可でSFTP接続のみ可能なユーザを作成しておくと便利
            - 参考: [sshで接続したくないけどSFTPは使いたい時の設定](https://qiita.com/nisihunabasi/items/aa0cf18dbf8fd4320b2c)
    - **sshdプロトコルの設定**
        - sshdプロトコル1には脆弱性があるらしいので、2に設定する（最近のディストリビューションは最初から設定されているが念の為）
    - **認証猶予時間と試行回数の制限**
        - 制限をきつくすると締め出されてしまう危険性もあるが、緩めに制限しておくと多少安心
2. **iptables**（ファイウォール関連）
    - **外部公開ポートの制限**
        - 外部に公開されているポートが多いと、それだけ攻撃を受けやすくなる
        - そのため、最低限外部接続可能なポート（httpポート, httpsポート, ssl（sftp）ポートを想定）以外のポートを閉じておく
            - 参考: [ファイアウォールiptablesを簡単解説](https://knowledge.sakura.ad.jp/4048/)
    - **ポートスキャン対策**
        - ポートスキャンとは、どのポートが開いているか外部から調査する攻撃手法
3. **services**（サービス関連）
    - **不要なサービスの停止**
        - 使われていないサービスが動いていると、管理コストが高くなり、想定外の動作が起こる可能性もあるため極力停止する
            - 参考: [Linuxで止めるべきサービスと止めないサービスの一覧](https://tech-mmmm.blogspot.com/2016/03/linux.html)

### sshd設定とユーザ管理
参考: [Ansible Playbookでユーザ管理（登録・削除）をまるっとやる](https://tech.smartcamp.co.jp/entry/2019/05/10/215035?utm_source=feed)
公式: [Best Practice - Ansible Documentation](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)

まずは、運用に工夫が必要なsshd設定とユーザ管理から設定していく

ディレクトリ構成は、Ansibleのベストラクティスを参考にしつつ以下のような構成とした

```bash
./
|_ production.yml # 本番サーバ用インベントリファイル
|_ main.yml # メインPlaybook｜playbooks/***.yml を読み込んで実行
|_ group_vars/ # 変数定義ファイル格納ディレクトリ
|   |_ all.yml # 今回は、ユーザ管理をこのファイルで行う運用を想定
|
|_ playbooks/ # 実際にサーバに対する操作を行うファイルを格納するディレクトリ｜インフラ管理者以外は触らない想定
|   |_ management.yml # 共通セキュリティ設定を行うPlaybook｜roles/management/tasks/main.yml のタスクを実行
|   |_ roles/ # Playbookで実行されるタスクを役割ごとに格納するディレクトリ
|       |_ management/ # このディレクトリ名（role）は親Playbookの名前と揃える
|           |_ tasks/  # 共通セキュリティ設定で実行するタスクを格納するディレクトリ
|           |   |_ main.yml # 共通セキュリティ設定で実行されるメインタスク定義ファイル
|           |   |_ admin_users.yml # 管理者ユーザ関連のタスク定義ファイル（main.yml から include される）
|           |   |_ users.yml # 一般ユーザ関連のタスク定義ファイル（main.yml から include される）
|           |
|           |_ templates/ # Jinja2テンプレートファイル格納ディレクトリ
|               |_ sshd_config.j2 # /etc/ssh/sshd_config に展開される設定テンプレートファイル
|
|_ ssh/ # ユーザごとの秘密鍵を格納するディレクトリ
        ## この部分の運用については考える必要があるかもしれない
```

#### production.yml
本番サーバ用のインベントリファイル

今回は `production.yml` のみ作成しているが、本来はステージングサーバや開発用サーバも用意していることがほとんどなので、`staging.yml`, `development.yml` 等のインベントリファイルも必要になるはず

インベントリファイルの基本的な記述内容は以下の通り

```yaml
---
all:
  hosts: # ホスト定義
    # hosts は playbooks/***.yml の名前に対応させるように定義する
    management: # management host
      ansible_host: 172.17.8.100 # 指定サーバのIPアドレス
      # vagrant host の SSH接続設定
      ansible_ssh_port: 22 # SSH接続ポートは通常 22番
      ansible_ssh_user: vagrant # SSH接続ユーザ名
      ansible_ssh_private_key_file: ../.vagrant/machines/default/virtualbox/private_key # SSH秘密鍵
      ansible_sudo_pass: vagrant # rootユーザパスワード
```

yamlファイル先頭の `---` はなくても動くが、慣習的につけることが多いようなのでつけている

今回の運用では、**ホスト（エイリアス）名は role名に対応させるようにしている**

今回の場合、playbooks/ 内にあるのは `management.yml`(共通セキュリティ設定のrole) のみなので、`management`ホスト（エイリアス）の接続情報のみ記述している

#### main.yml
Playbook実行時のエントリーファイル

playbooks/ 内のroleごとのPlaybookファイルをimportするだけ

```yaml
---
# 共通セキュリティ基本設定
- import_playbook: playbooks/management.yml
```

#### group_vars/all.yml
各種変数を定義するためのファイル（このファイルはPlaybook実行時に自動的に読み込まれる）

ユーザ管理をこのファイルで行う想定で記述している

```yaml
---
# ユーザ設定
## ユーザを追加・削除する場合はここを変更する

# 管理者ユーザ: sshログイン & sudo権限あり
admin_users:
  - name: 'vagrant-admin'
    uid: 1001 # 重複しないユーザIDを指定すること

# 一般ユーザ: sftp接続のみ可
users:
  - name: 'vagrant-user'
    uid: 2001

# グループ設定
## 基本的に編集しない
admin_group: 'admin'
user_group: 'developers'
```

#### playbooks/management.yml
共通セキュリティ設定を定義するPlaybookファイル

運用上は、以下のような動作をするのが分かりやすいかと考え、設定している

1. Playbookファイル名＝role名とする
2. インベントリファイル内の、role名に対応するホスト名の接続情報を使用してサーバに接続
3. playbooks/roles/ ディレクトリ内の対応するrole名のタスクを実行

```yaml
---
- hosts: management
  become: true # root権限で実行
  roles:
    - management # ./roles/management/tasks/main.yml を実行
```

#### playbooks/roles/management/tasks/main.yml
対応するrole名のPlaybookから呼び出される各種タスクを定義するファイル

今回は、以下のようにタスクを定義している

1. 管理者ユーザ関連タスク:
    - `admin_users.yml` を include
2. 一般ユーザ関連タスク:
    - `users.yml` を include
3. sshd設定関連タスク:
    - `sshd_config.j2` テンプレートファイルを `/etc/ssh/sshd_config` に展開し、sshd再起動

```yaml
---
# 管理者ユーザ設定
## includeモジュールで 別ファイルの中身をそのまま展開できる
- include: admin_users.yml

# 一般ユーザ設定
- include: users.yml

- name: sshd設定
  # Jinja2テンプレートエンジンを利用してテンプレートファイルを展開してアップロード
  # templateモジュール｜src=<テンプレートファイル> dest=<アップロード先ファイルパス> ...
  ## テンプレートファイル内では {{変数名}} で変数を展開できる（詳しくは Jinja2 公式リファレンス参照）
  template: src=../templates/sshd_config.j2 dest=/etc/ssh/sshd_config owner=root group=root mode=0600

- name: sshd再起動
  # serviceモジュール｜name=<サービス名> state=<reloaded|restarted|started|stopped> ...
  service: name=sshd state=restarted
```

#### playbooks/roles/management/tasks/admin_users.yml
```yaml
---
- name: 管理者グループ作成
  # groupモジュール｜name=<グループ名> state=<present（作成）|absent（削除）>
  # {{変数名}} で変数を展開可能
  group: name={{ admin_group }} state=present

- name: 管理者グループをsudoersに追加
  # モジュールは `module_name: param1=var1 ...`（1行表記）という書き方だけでなく
  ## `module_name:
  ##    param1: var1
  ##    ... `（複数行表記）という書き方も可能
  lineinfile:
    path: /etc/sudoers
    regexp: "%{{ admin_group }}" # "%グループ名" にマッチする行を line で指定した文字列で置換
    line: "%{{ admin_group }} ALL=(ALL) NOPASSWD: ALL"

- name: 管理者ユーザ作成
  # with_items: '配列' で配列を処理できる｜foreach item in 配列
  ## ユーザ作成時に SSH鍵ペアも作成しておく
  user: name={{ item.name }} group={{ admin_group }} groups={{ admin_group }} uid={{ item.uid }} generate_ssh_key=yes
  with_items: '{{ admin_users }}'

- name: 実際に管理者グループに属するユーザのリストを取得
  shell: 'getent group {{ admin_group }} | cut -d: -f4 | tr "," "\n"'
  register: present_sudoers # => シェルの実行結果を present_sudoers という変数に代入

- name: すでに存在しないユーザを削除
  # ユーザのホームディレクトリごと削除
  user: name={{ item }} state=absent remove=yes
  # 実際に管理者グループに属するユーザと admin_users に設定されたユーザの差分 => 削除するべきユーザ
  ## `[{key: val}, ...] | map(attribute="key") | list` で dictの指定キーのみを取り出してリスト化可能
  with_items: '{{ present_sudoers.stdout_lines | difference(admin_users | map(attribute="name") | list) }}'
  ignore_errors: yes # ユーザが削除済みの場合があるためエラーは無視

- name: 管理者ユーザの公開鍵登録
  copy:
    src: '/home/{{ item.name }}/.ssh/id_rsa.pub'
    dest: '/home/{{ item.name }}/.ssh/authorized_keys'
    owner: '{{ item.name }}'
    group: '{{ admin_group }}'
    mode: 0600 # パーミッションは8進数で記述すること
    remote_src: yes # リモートサーバ内でファイルコピー
  with_items: '{{ admin_users }}'

- name: 管理者ユーザの秘密鍵ダウンロード
  fetch: src=/home/{{ item.name }}/.ssh/id_rsa dest=../ssh/{{ item.name }}-id_rsa flat=yes
  with_items: '{{ admin_users }}'
```

#### playbooks/roles/management/tasks/users.yml
`admin_users.yml` とほぼ同じ内容のため省略

#### playbooks/roles/management/templates/sshd_config.j2
sshd設定ファイルの内容をJinja2テンプレートを用いて記述している

Jinja2で使える表記法については、[公式リファレンス](https://jinja.palletsprojects.com/en/2.10.x/templates/)を参照

なお、SSH接続ポートの変更は、Firewall（iptables）の設定とも関わってくるため、ここではまだ設定していない

```conf
# (略)

# sshd protocol
Protocol 2

# 認証試行時間: 30秒
LoginGraceTime 30

# 認証試行回数: 30回
MaxAuthTries 30

# rootログイン不可
PermitRootLogin no

# パスワード認証不可｜公開鍵認証のみ許可
PasswordAuthentication no
ChallengeResponseAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile	.ssh/authorized_keys

# sftp で chroot させたい場合は internal-sftp を使う必要あり
#Subsystem  sftp  /usr/libexec/openssh/sftp-server
Subsystem  sftp  internal-sftp

# sftpのみ許可するユーザグループの設定
## {{変数名}} で変数を展開可能
Match Group {{ user_group }}
    # ログインシェルに internal-sftp を強制
    ## => ssh接続はできず、sftp接続のみ可能になる
    ForceCommand internal-sftp
```

#### Playbook実行
ここまでで一旦、動作確認を行う

```bash
# Playbook実行
$ ansible-playbook -i production.yml main.yml
    :
management  : ok=14  changed=12  unreachable=0  failed=0  skipped=2  rescued=0  ignored=0

## => ssh/vagrant-admin-id_rsa, vagrant-user-id_rsa が保存されるはず

# 作成された管理者ユーザでSSH接続確認
$ chown 600 ssh/vagrant-admin-id_rsa
$ ssh -i ssh/vagrant-admin-id_rsa vagrant-admin@172.17.8.100

---
## => 問題なく接続できたらOK
[vagrant-admin ~]$ exit
---

# 一般ユーザでSSH接続試行
$ chown 600 ssh/vagrant-user-id_rsa
$ ssh -i ssh/vagrant-user-id_rsa vagrant-user@172.17.8.100

## => This service allows sftp connections only.
### 上記のようなエラーが出て接続を拒否されればOK

# 一般ユーザでSFTP接続確認
$ sftp -i ssh/vagrant-user-id_rsa vagrant-user@172.17.8.100

---
## => 問題なく接続できたらOK
sftp> exit
```
