# SELinuxの無効化

SELinuxはセキュアなサーバ運用のために有用ではあるが、SSH接続ポートの変更手順が複雑化するなど、管理コストが高くなることが多いため、ここでは無効化して運用することにする

ただしサーバセキュリティは、場合によっては経営に直接的な影響を与える可能性もあるため、この部分の判断は可能な限り複数人で慎重に検討する必要がある

## Playbook構成

```bash
./
|_ production.yml
|_ main.yml
|_ group_vars/
|   |_ all.yml # 全グループ共通の変数定義ファイル
|
|_ playbooks/
    |_ management.yml # 共通セキュリティ設定を行うPlaybook｜roles/management/tasks/main.yml のタスクを実行
    |_ roles/
        |_ management/
            |_ tasks/
                |_ main.yml # 共通セキュリティ設定で実行されるメインタスク定義ファイル
                |_ selinux_disabled.yml # SELinux無効化のタスク定義ファイル（main.yml から include される）

```

### production.yml
本番サーバ用のインベントリファイル

今回は `production.yml` のみ作成しているが、本来はステージングサーバや開発用サーバも用意していることがほとんどなので、`staging.yml`, `development.yml` 等のインベントリファイルも必要になるはず

インベントリファイルの基本的な記述内容は以下の通り

```yaml
---
# 各グループ名は group_vars/***/, playbooks/***.yml と統一する
management: # 共通セキュリティ設定グループ
  hosts: # ホスト定義
    web: # ホスト名は基本的に web で統一する
      ansible_host: 172.17.8.100 # 指定サーバのIPアドレス
      ansible_ssh_port: 22 # SSH接続ポートは通常 22番
      ansible_ssh_user: vagrant # SSH接続ユーザ名
      ansible_ssh_private_key_file: ../.vagrant/machines/default/virtualbox/private_key # SSH秘密鍵
      ansible_sudo_pass: vagrant # rootユーザパスワード
```

yamlファイル先頭の `---` はなくても動くが、慣習的につけることが多いようなのでつけている

### group_vars/all.yml
全グループで共通して使用可能な変数を定義するためのファイル（このファイルはPlaybook実行時に自動的に読み込まれる）

ここでは、SELinux無効化時に必要な再起動の待ち時間のみ定義している

```yaml
---
# サーバ再起動待ちのタイムアウト時間 [秒]
## Vagrant環境だと実際には reboot が起こらないため、短めのタイムアウト時間を指定した方が良い
## 通常のサーバであれば、それなりに長いタイムアウト時間を指定する必要がある
reboot_wait_timeout: 10
```

### main.yml
Playbook実行時のエントリーファイル

`playbooks`ディレクトリ内のRoleごとのPlaybookファイルをimportするだけ

```yaml
---
# 共通セキュリティ基本設定
- import_playbook: playbooks/management.yml
```

### playbooks/management.yml
共通セキュリティ設定を定義するPlaybookファイル

```yaml
---
- hosts: web # ホスト名は基本的に web で統一する
  become: true # root権限で実行
  roles:
    - management # ./roles/management/tasks/main.yml を実行
```

### playbooks/roles/management/tasks/main.yml
対応するrole名のPlaybookから呼び出される各種タスクを定義するファイル

```yaml
---
# SELinux無効化設定
## includeモジュールで 別ファイルの中身をそのまま展開できる
- include: selinux_disabled.yml
```

### playbooks/roles/management/tasks/selinux_disabled.yml
SELinuxを無効化し、サーバマシンを再起動するタスクが定義してある

```yaml
---
# SELinux が有効化されていると SSHポートの変更等が面倒なので無効化しておく
## 参考: http://redj.hatenablog.com/entry/2018/04/22/135933

- name: Ansibleの selinuxモジュールを使うためのパッケージをインストール
  # yumモジュール｜name=<パッケージ名> state=<present|absent> ...
  yum: name=libselinux-python state=present

- name: SELinuxの無効化
  selinux: state=disabled
  register: selinux # => selinuxモジュールの実行結果を selinux 変数に代入

- name: マシンのリブート
  shell: "sleep 2 && reboot"
  async: 1 # シェルを同期的に実行
  poll: 0
  when: selinux.reboot_required # selinuxが再起動を要求した場合に実行

- name: マシンの停止を待ち合わせ
  # local_actionモジュール｜Ansible実行マシンに対してコマンドを実行
  ## inventory_hostname: 現在Playbookが実行中のインベントリホスト名が入っている
  ## インベントリホストに対して状態を問い合わせ、状態が stopped になるまで待つ 
  local_action: wait_for host={{ inventory_hostname }} port={{ ansible_ssh_port }} state=stopped
  when: selinux.reboot_required # selinuxが再起動を要求した場合に実行
  become: false # local_actionを使う場合は become=false にしておかないと rootパスワード周りでエラーが起こる

- name: マシンの起動を待ち合わせ
  # インベントリホスト(ssh port: 22)に対して状態を問い合わせ、状態が started になるまで待つ
  ## reboot_wait_timeout で指定された秒数が経過したら強制的に次のタスクへ移行
  local_action: wait_for host={{ inventory_hostname }} port={{ ansible_ssh_port }} state=started timeout={{ reboot_wait_timeout }}
  when: selinux.reboot_required # selinuxが再起動を要求した場合に実行
  become: false
  ignore_errors: true # vagrant環境だといつまで経ってもこのタスクは終わらないため、タイムアウトしたらそのまま無視する
```

### Playbook実行
ここまでで一旦、動作確認を行う

```bash
# Playbook実行
$ ansible-playbook -i production.yml main.yml
    :
management  : ok=5  changed=5  unreachable=0  failed=0  skipped=2  rescued=0  ignored=0

## => サーバマシンが再起動され、SELinuxが無効化された状態になる
### ※ Vagrantの場合は実際には再起動しないが、SELinuxはちゃんと無効化されている
```
