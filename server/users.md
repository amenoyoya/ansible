# ユーザ管理とsshd設定（＋iptables 設定）

参考: [Ansible Playbookでユーザ管理（登録・削除）をまるっとやる](https://tech.smartcamp.co.jp/entry/2019/05/10/215035?utm_source=feed)

## Playbook構成

```bash
./
|_ production.yml
|_ main.yml
|_ group_vars/
|   |_ all.yml
|   |_ management/ # グループ名ディレクトリ配下のファイルはPlaybook実行時に自動的に読み込まれる
|       |_ ports.yml # ポート設定関連の変数定義ファイル
|       |_ users.yml # ユーザ管理はこのファイルで行う想定
|
|_ playbooks/
|   |_ management.yml
|   |_ roles/
|       |_ management/
|           |_ tasks/
|           |   |_ main.yml
|           |   |_ selinux_disabled.yml
|           |   |_ admin_users.yml # 管理者ユーザ関連のタスク定義ファイル（main.yml から include される）
|           |   |_ users.yml # 一般ユーザ関連のタスク定義ファイル（main.yml から include される）
|           |   |_ services.yml # sshd, iptables関連のタスク定義ファイル（main.yml から include される）
|           |
|           |_ templates/ # Jinja2テンプレートファイル格納ディレクトリ
|               |_ sshd_config.j2 # /etc/ssh/sshd_config に展開される設定テンプレートファイル
|               |_ iptables.j2 # /etc/sysconfig/iptables に展開される設定テンプレートファイル
|
|_ ssh/ # ユーザごとの秘密鍵を格納するディレクトリ
        ## この部分の運用については考える必要があるかもしれない
```

### group_vars/management/ports.yml
```yaml
---
# SSH接続ポート
## 推測されにくく、他のアプリケーションポートと重複しないポートを指定する
## 開発段階では、22 のままにしておいた方が楽
ssh_port: 22

# 外部からのアクセスを許可するポート
accept_ports:
  # httpポート
  - port: 80
    protocol: 'tcp'
  
  # httpsポート
  - port: 443
    protocol: 'tcp'
```

### group_vars/management/users.yml
ユーザの追加・削除をしたい場合は、この変数定義ファイルに設定を記述する

SSH接続してサーバ内の各種操作が可能なユーザは `admin_users`, FTP（SFTP）接続してファイルの更新だけが可能なユーザは `users` に設定する

各ユーザがサーバ接続するための鍵ファイルは `ssh`ディレクトリに生成される

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

# ---

# ユーザグループ設定
## 基本的に編集しない
admin_group: 'admin'
user_group: 'developers'
```

### playbooks/roles/management/tasks/main.yml
```yaml
---
# SELinux無効化設定
## includeモジュールで 別ファイルの中身をそのまま展開できる
- include: selinux_disabled.yml

# 管理者ユーザ設定
- include: admin_users.yml

# 一般ユーザ設定
- include: users.yml

# sshd, iptables設定
- include: services.yml
```

### playbooks/roles/management/tasks/admin_users.yml
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

### playbooks/roles/management/tasks/users.yml
`admin_users.yml` とほぼ同じ内容のため省略

### playbooks/roles/management/tasks/services.yml
sshd と iptables の設定タスクを定義するが、注意点として、CentOS 7 以降は iptables の代わりに firewalld がデフォルトのアクセス制御サービスとなっているため、iptables を使うように設定する

```yaml
---
- name: sshd設定
  # Jinja2テンプレートエンジンを利用してテンプレートファイルを展開してアップロード
  # templateモジュール｜src=<テンプレートファイル> dest=<アップロード先ファイルパス> ...
  ## テンプレートファイル内では {{変数名}} で変数を展開できる（詳しくは Jinja2 公式リファレンス参照）
  template: src=../templates/sshd_config.j2 dest=/etc/ssh/sshd_config owner=root group=root mode=0600

- name: sshd再起動＆スタートアップ登録
  # serviceモジュール｜name=<サービス名> state=<reloaded|restarted|started|stopped> enabled=<false|true> ...
  ## enabled=true にするとスタートアップサービスに登録することができる
  service: name=sshd state=restarted enabled=true

- name: iptables設定
  template: src=../templates/iptables.j2 dest=/etc/sysconfig/iptables owner=root group=root mode=0600

# CentOS 7 以降は iptables が入っていないことがあるためインストールする
- name: iptablesインストール
  # yumモジュール｜name=<パッケージ名> state=<present|absent> ...
  yum: name=iptables state=present

# CentOS 7 以降は iptables の代わりに firewalld がデフォルトになっているため停止する
- name: firewalld停止＆スタートアップ削除
  service: name=firewalld state=stopped enabled=false
  ignore_errors: yes # CentOS 6 なら firewalld は存在しないためエラーは無視

- name: iptables（再）起動＆スタートアップ登録
  service: name=firewalld state=restarted enabled=true
```

### playbooks/roles/management/templates/sshd_config.j2
sshd設定ファイルの内容をJinja2テンプレートを用いて記述している

Jinja2で使える表記法については、[公式リファレンス](https://jinja.palletsprojects.com/en/2.10.x/templates/)を参照

```conf
# （一部設定のみ抜粋）

# sshd protocol
Protocol 2

# sshd port
Port {{ ssh_port }}

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

### playbooks/roles/management/templates/iptables.j2
iptables の設定をテンプレート化している（省略）

### Playbook実行
設定できたら動作確認を行う

```bash
# Playbook実行
$ ansible-playbook -i production.yml main.yml
    :
management  : ok=19  changed=12  unreachable=0  failed=0  skipped=7  rescued=0  ignored=0

## => ssh/vagrant-admin-id_rsa, vagrant-user-id_rsa が保存されるはず

# 作成された管理者ユーザでSSH接続確認
$ chown 600 ssh/vagrant-admin-id_rsa
$ ssh -i ssh/vagrant-admin-id_rsa vagrant-admin@172.17.8.100

---
## => 問題なく接続できたら、ポートの確認を行う

# iptables の開放ポートを確認
[vagrant-admin ~]$ sudo iptables -nL

# SELinuxを有効化している場合: SELinuxのポリシーを確認
## 普通に semanage を実行すると UnicodeEncodingError が起こるため PYTHONIOENCODING環境変数を設定しながら実行する
[vagrant-admin ~]$ sudo PYTHONIOENCODING=utf-8 python /usr/sbin/semanage port -l

## => iptables, SELinux の開放ポート（特にSSHポート）が想定通り設定されていればOK

# SSH切断
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
