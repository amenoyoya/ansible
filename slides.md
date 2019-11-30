---
marp: true
---
<!-- $theme: gaia -->
<!-- $size: 4:3 -->
<!-- page_number: true -->
<!-- paginate: true -->
# Ansible｜サーバ構築テンプレート作成

## Ansibleによる構成管理

---

### べき等性
べき等性とは、そのスクリプトを一回実行した結果と複数回実行した結果が変わらないことを示す

関数で言うところの参照透過性、副作用のない関数とほぼ同等の意味合いと考えて良い

構成管理においても、このべき等性が担保されていることが重要である

同じスクリプトを実行して、違う環境が構成されてしまっては構成管理ツールの意味がなくなってしまうからである

---

![idempotency.png](https://github.com/amenoyoya/ansible/blob/master/img/idempotency.png?raw=true)

べき等性を担保するためには以下の点を意識してスクリプトを書くことが望ましい

- インストールするパッケージのバージョンを指定する
- スクリプトが実行された環境の情報を取得し、差分を処理する

---

## Ansibleインストール
Ansibleはローカルマシンにインストールする必要がある

ここでは、Windows 10 環境と Ubuntu 18.04 環境におけるインストール方法を紹介する

---

### Ansibleインストール on Windows 10
ここでは、Windows Subsystem Linux（WSL）を使うことにする

`Win + X` |> `A` => 管理者権限でPowerShell起動

```powershell
# Windows Subsystem Linux を有効化する
> Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
この操作を完了するために、今すぐコンピューターを再起動しますか?
[Y] Yes  [N] No  [?] ヘルプ (既定値は "Y"): # そのままENTERして再起動

# 再起動したら Ubuntu 18.04 ディストロパッケージをダウンロード
## 「ダウンロード」ディレクトリに ubuntu1804.appx というファイル名でダウンロード
> Invoke-WebRequest -Uri https://aka.ms/wsl-ubuntu-1804 -OutFile ~\Downloads\ubuntu1804.appx -UseBasicParsing

# ダウンロードしたディストロパッケージをWSLに追加
> Add-AppxPackage ~\Downloads\ubuntu1804.appx
```

---

スタートメニューに「Ubuntu 18.04」が追加されるため、起動する

```bash
# 初回起動時は初期設定が必要
Installing, this may take a few minutes...
Please create a default UNIX user account. The username does not need to match your Windows username.
For more information visit: https://aka.ms/wslusers
Enter new UNIX username: # ログインユーザ名を設定
Enter new UNIX password: # ログインパスワードを設定
Retype new UNIX password: # パスワードをもう一度入力
```

以降は **Ansibleインストール on Ubuntu 18.04** の項を参照

---

### Ansibleインストール on Ubuntu 18.04
```bash
# Ansibleインストール用のリポジトリ追加
$ sudo apt update && apt install software-properties-common
$ sudo apt-add-repository --yes --update ppa:ansible/ansible

# Ansibleインストール
$ sudo apt install ansible

# バージョン確認
$ ansible --version
ansible 2.9.1
```

---

# AnsibleによるVagrant仮想サーバ構成管理

---

## Vagrant仮想サーバ

Vagarantとは、VirtualBox等のホスト型仮想環境の構築・設定を支援する自動化ツールである

まずは、本物のサーバをいじる前に、VirtualBox＋Vagrantで作成した仮想サーバを用いてAnsibleの動作確認を行っていく

---

## VirtualBox, Vagrantのインストール
仮想マシンバックエンドに VirtualBox を採用し、VirtualBox + Vagrant 環境を準備する

ここでは、Windows 10 環境と Ubuntu 18.04 環境におけるインストール方法を紹介する

---

### on Windows 10
`Win + X` => `A` |> 管理者権限PowerShell

```powershell
# chocolatey で virtualbox, vagrant インストール
## chocolatey を使っていない場合は、公式のインストーラを用いてインストールしても良い
> choco install -y virtualbox
> choco install -y vagrant

# vagrantプラグイン インストール
> vagrant plugin install vagrant-vbguest # VagrantのゲストOS-カーネル間のバージョン不一致解決用プラグイン
> vagrant plugin install vagrant-winnfsd # WindowsのNTFSマウントで、LinuxのNFSマウントを可能にするプラグイン

# シンボリックリンクを有効化
> fsutil behavior set SymlinkEvaluation L2L:1 R2R:1 L2R:1 R2L:1
```

---

### on Ubuntu 18.04
```bash
# virtualbox. vagrant インストール
$ sudo apt install -y virtualbox
$ sudo apt install -y virtualbox-ext-pack
$ sudo apt install -y vagrant

# vagrantプラグイン インストール
$ vagrant plugin install vagrant-vbguest # VagrantのゲストOS-カーネル間のバージョン不一致解決用プラグイン
```

---

## CentOS7 仮想マシン構築

Vagrantは `Vagrantfile` に仮想マシン設定を記述して `vagrant up` コマンドを叩くだけで仮想マシンを自動的に構築することができる

ここでは CentOS7 仮想マシンを構築するため、`Vagrantfile`を以下のように記述する

---

```ruby
# -*- mode: ruby -*-
# vi: set ft=ruby :

ssh_port = 22 # ssh接続ポート

Vagrant.configure("2") do |config|
  config.vm.box = "centos/7"
  config.vbguest.auto_update = false # host-guest間の差分アップデートを無効化

  # 仮想マシの private IPアドレス設定
  config.vm.network "private_network", ip: "172.17.8.100"

  # ssh接続ポート設定
  config.ssh.guest_port = ssh_port
  config.vm.network "forwarded_port", guest: ssh_port, host: 22222, id: "ssh"
end
```

---

記述したら、Vagrantfileのあるディレクトリで以下のコマンドを実行し仮想マシンを起動する

```bash
# Vagrantfile設定に従って仮想マシン起動
## 初回起動時はBoxファイル（仮想OSのイメージファイル）ダウンロードに時間がかかる
$ vagrant up

# なお、仮想マシンを終了する場合は halt コマンドを実行する
# $ vagrant halt
```

---

仮想マシンが起動したら、以下の設定で仮想マシンにSSH接続してみる

- ユーザ名: `vagrant`
- IPアドレス: `172.17.8.100` (Vagrantfileで設定したIPアドレス)
- SSH秘密鍵: `.vagrant/machines/default/virtualbox/private_key`

```bash
# Vagrant仮想マシンにSSH接続
$ ssh -i ./.vagrant/machines/default/virtualbox/private_key vagrant@172.17.8.100

---
# 問題なく接続できたら、そのまま exit でOK
[vagrant@localhost ~]$ exit
```

---

# Ansibleを使ってみる

## インベントリファイルの作成
Ansibleの接続先サーバ情報等を記述した設定ファイルを**インベントリファイル**と呼ぶ

インベントリファイル名は任意だが、ここでは `servers.yml` というファイル名にする

なお、インベントリファイルの形式としては**ini形式**と**yaml形式**があるが、ここではyaml形式を採用する

`servers.yml` にサーバ情報を以下の通り記述する（yaml形式ではインデントにも意味があるため、インデント幅に注意すること）

---

```yaml
all:
  hosts: # ホスト定義
    vagrant: # vagrant host
      ansible_host: 172.17.8.100 # 指定サーバのIPアドレス
  vars:  # 変数定義
    # SSH接続設定変数
    ansible_ssh_port: 22 # SSH接続ポートは通常 22番
    ansible_ssh_user: vagrant # SSH接続ユーザ名
    ansible_ssh_private_key_file: ./.vagrant/machines/default/virtualbox/private_key # SSH秘密鍵
    ansible_sudo_pass: vagrant # rootユーザパスワード
```

---

意味としては以下のようになる

- hosts設定:
    - サーバIPアドレス `172.17.8.100` を `vagrant` というエイリアス名に設定
- vars設定: ここではSSH接続情報を記述
    - `ansible_ssh_port`: SSH接続ポート｜基本的に`22`を指定
    - `ansible_ssh_user`: SSH接続ユーザ
    - `ansible_ssh_private_key_file`: SSH接続用秘密鍵のパス
        - 鍵ファイルではなくパスワードで接続する場合は `ansible_ssh_pass` を指定する
    - `ansible_sudo_pass`: rootユーザパスワード｜rootユーザでSSH接続する場合は `ansible_ssh_pass` と同一になる

---

## 単一コマンドの実行

インベントリファイルを作成したら、Ansibleでサーバ内のコマンドを実行させてみる

`servers.yml` があるディレクトリ内で以下のコマンドを実行

```bash
# Ansibleでサーバ内に接続し hostname コマンドを実行
## ansible <エイリアス名>: エイリアス名に設定されたサーバに接続する
## -i <インベントリファイル>: インベントリファイルを指定
## -m <モジュール名>: Ansibleの実行モジュールを指定（ここでは command を指定）
## -a <引数>: Ansible実行モジュールの引数を指定
### => 今回は command モジュールのため hostname コマンドを実行するという意味になる
$ ansible vagrant -i servers.yml -m command -a "hostname" 

## => localhost.localdomain
### ここまでの設定が正しくできていれば上記のようなホスト名が返ってくるはず
```

---

## Playbookによるサーバ構成自動化

AnsibleにはPlaybookという、サーバ構成・状態を定義し、自動的に構成を行うことのできる仕組みがある

ここでは、サーバにユーザを新規作成し、SSH鍵を使ってSSH接続できるように構成する

Playbookファイルもyaml形式で記述し、ファイル名は任意だが、ここでは `playbook.yml` として以下のように記述する（各タスクの内容は、コメントの通りである）

---

```yaml
- hosts: vagrant # イベントリファイルに記述された vagrant ホスト（エイリアス）に対して実行
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
      fetch: src=/home/testuser/.ssh/id_rsa dest=./ssh/testuser-id_rsa flat=yes
```

---

playbook.yml が作成できたら、以下のコマンドでPlaybookを実行

```bash
# ansible-playbook -i <インベントリファイル> <Playbookファイル>
$ ansible-playbook -i servers.yml playbook.yml
    :
vagrant  : ok=6  changed=6  unreachable=0  failed=0  skipped=0  rescued=0  ignored=0
```

実行すると、`testuser`ユーザが作成され、そのユーザでログインするためのSSH秘密鍵を `./ssh/testuser-id_rsa` に保存することができるはず

---

なお、もう一度Playbookを実行すると `changed=0` となり、最終的なサーバ構成・状態は同一になることが担保されている（**べき等性**）

```bash
# もう一度Playbookを実行した場合
$ ansible-playbook -i servers.yml playbook.yml
    :
## => changed=0 となり、現在のサーバの状態に合わせて何の変更も加えなかったことが分かる
vagrant  : ok=6  changed=0  unreachable=0  failed=0  skipped=0  rescued=0  ignored=0
```

---

## 複数のSSH接続ユーザ設定

ここまで設定すると `testuser` ユーザでもSSH接続できるようになる

まずは普通に `ssh`コマンドで接続してみる

```bash
# Ansibleにより生成＆ダウンロードされたSSH秘密鍵のパーミッションを変更
$ chmod 600 ./ssh/testuser-id_rsa

# testuserユーザでSSH接続
$ ssh -i ./ssh/testuser-id_rsa testuser@172.17.8.100

---
# SSH接続できることを確認したらそのまま exit
[testuser ~]$ exit
```

---

続いてインベントリファイル `servers.yml` に `testuser`ユーザでのSSH接続設定を追加する（ホストエイリアスごとに `ansible_***` の設定を記述することができるため、SSH接続設定もそのような記述方法に変更している）

```yaml
all:
  hosts: # ホスト定義
    vagrant: # vagrant host
      ansible_host: 172.17.8.100 # 指定サーバのIPアドレス
      # vagrant host の SSH接続設定
      ansible_ssh_port: 22 # SSH接続ポートは通常 22番
      ansible_ssh_user: vagrant # SSH接続ユーザ名
      ansible_ssh_private_key_file: ./.vagrant/machines/default/virtualbox/private_key # SSH秘密鍵
      ansible_sudo_pass: vagrant # rootユーザパスワード
    test: # test host
      ansible_host: 172.17.8.100
      # test host の SSH接続設定
      ansible_ssh_port: 22
      ansible_ssh_user: testuser # testuserで接続
      ansible_ssh_private_key_file: ./ssh/testuser-id_rsa
      ansible_sudo_pass: vagrant
```

---

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

---

# おまけ

## 仮想マシンの初期化

サーバの設定を色々していると、設定を間違えてSSH接続できなくなったりなどのトラブルが起こり得る

そのような場合は、Vagrant仮想マシンを一度破壊して再構築してしまうのが早い

---

```bash
# vagrant仮想マシンの破壊
$ vagrant destroy -y

# vagrant仮想マシンの構築＆起動
$ vagrant up

# 再構築するとSSH鍵の設定が変更されるため、登録済みの鍵情報を削除する必要がある
## Windows環境では ssh-keygen が使えないため、直接 ~/.ssh/known_hosts を編集する
$ ssh-keygen -f ~/.ssh/known_hosts -R "172.17.8.100"
```

---

# サーバ構成のテンプレート化

## CentOS 7 サーバ構築

仕事では CentOS 6, 7系のVPSを使うことが多いため、ここでは CentOS 7 を基本としてテンプレートを作成していく

なお、完成したPlaybookは https://github.com/amenoyoya/ansible/tree/master/vagrant/ansible に置いてある

---

## 共通セキュリティ設定

- 参考: [そこそこセキュアなlinuxサーバーを作る](https://qiita.com/cocuh/items/e7c305ccffb6841d109c)

とりあえず行わなければならない基本的なセキュリティ設定は以下の通り

1. services（サービス関連）
2. sshd（SSH接続関連）
3. iptables（Firewall関連）

---
### services（サービス関連）
- **不要なサービスの停止**
    - 使われていないサービスが動いていると、管理コストが高くなり、想定外の動作が起こる可能性もあるため極力停止する
        - 参考: [Linuxで止めるべきサービスと止めないサービスの一覧](https://tech-mmmm.blogspot.com/2016/03/linux.html)
- **SELinux関連設定**
    - CentOS 7 など、モダンなOSでは、SELinuxという、Linuxのカーネルに強制アクセス制御 (MAC) 機能を付加するモジュールが有効化されている  
    - 管理が複雑化したり、想定外の動作が起きたりすることもあるため無効化することも多いが、セキュリティ的にはなるべく有効化しておきたい

---

### sshd（SSH接続関連）その1
- **ポート変更**
    - SSHのデフォルト接続ポート25番は一般に知れ渡っており標的の対象となりやすいため、別のポートに変更する
- **rootログイン不可**
    - rootはすべてのサーバにあるユーザであるため総当り攻撃される危険性がある
    - root権限はサーバ内のあらゆる操作が可能であるため乗っ取られると非常に危険
- **パスワード認証不可**
    - パスワード認証は総当り攻撃の対象になるため禁止する（公開鍵認証のみ許可とする）

---

### sshd（SSH接続関連）その2
- **SSH接続できないユーザの作成**
    - Web制作をしていると、デザイナやコーダーなどがFTP（SFTP）でファイルアップロードしたいという要望があるため、SSH接続不可でSFTP接続のみ可能なユーザを作成しておくと便利
        - 参考: [sshで接続したくないけどSFTPは使いたい時の設定](https://qiita.com/nisihunabasi/items/aa0cf18dbf8fd4320b2c)
- **sshdプロトコルの設定**
    - sshdプロトコル1には脆弱性があるらしいので、2に設定する（最近のディストリビューションは最初から設定されているが念の為）
- **認証猶予時間と試行回数の制限**
    - 制限をきつくすると締め出されてしまう危険性もあるが、緩めに制限しておくと多少安心

---

### iptables（ファイウォール関連）
- **外部公開ポートの制限**
    - 外部に公開されているポートが多いと、それだけ攻撃を受けやすくなる
    - そのため、最低限外部接続可能なポート（httpポート, httpsポート, ssl（sftp）ポート等）以外のポートを閉じておく
        - 参考: [ファイアウォールiptablesを簡単解説](https://knowledge.sakura.ad.jp/4048/)
- **ポートスキャン対策**
    - ポートスキャンとは、どのポートが開いているか外部から調査する攻撃手法

---

## ディレクトリ構成
ディレクトリ構成は、Ansibleのベストラクティスを参考にしつつ以下のような構成とした

- 参考: [Best Practice - Ansible Documentation](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)

なお、共通セキュリティ設定関連は、**management**グループとしてまとめることとした

---

```bash
./
|_ production.yml # 本番サーバ用インベントリファイル
|_ main.yml # メインPlaybook｜playbooks/***.yml を読み込んで実行
|_ group_vars/ # 変数定義ファイル格納ディレクトリ
|   |_ all.yml # 全グループ共通の変数定義ファイル
|   |_ management/ # 共通セキュリティ設定関連の変数定義ファイルの格納ディレクトリ
|       |_ settings.yml # 共通セキュリティ設定の変数定義ファイル
|       |_ ports.yml # ポート設定関連の変数定義ファイル
|       |_ users.yml # ユーザ管理はこのファイルで行う想定
|
|_ playbooks/ # 実際にサーバに対する操作を行うファイルを格納するディレクトリ｜インフラ管理者以外は触らない想定
|   |_ management.yml # 共通セキュリティ設定を行うPlaybook｜roles/management/tasks/main.yml のタスクを実行
|   |_ roles/ # Playbookで実行されるタスクを役割ごとに格納するディレクトリ
|       |_ management/ # このディレクトリ名（role）は親Playbookの名前と揃える
|           |_ tasks/  # 共通セキュリティ設定で実行するタスクを格納するディレクトリ
|           |   |_ main.yml # 共通セキュリティ設定で実行されるメインタスク定義ファイル
|           |   |_ admin_users.yml # 管理者ユーザ関連のタスク定義ファイル（main.yml から include される）
|           |   |_ users.yml # 一般ユーザ関連のタスク定義ファイル（main.yml から include される）
|           |   |_ services.yml # sshd, iptables関連のタスク定義ファイル（main.yml から include される）
|           |   |_ selinux.yml # SELinux関連のタスク定義ファイル（main.yml から include される）
|           |   |_ selinux_disabled.yml # SELinux無効化のタスク定義ファイル（selinux.yml から include される）
|           |
|           |_ templates/ # Jinja2テンプレートファイル格納ディレクトリ
|               |_ sshd_config.j2 # /etc/ssh/sshd_config に展開される設定テンプレートファイル
|               |_ iptables.j2 # /etc/sysconfig/iptables に展開される設定テンプレートファイル
|
|_ ssh/ # ユーザごとの秘密鍵を格納するディレクトリ
        ## この部分の運用については考える必要があるかもしれない
```

---

運用方法にもよるが、基本的にグループ名とPlaybook名、Role名は統一したほうが分かりやすい

今回の場合、以下の名前はすべて `management` で統一する

- インベントリファイルに記述するグループ名
- `group_vars`ディレクトリ配下の、グループ内変数ファイル格納ディレクトリ名
- `playbooks`ディレクトリ配下の、実行Playbookファイル名
- `playbooks/roles`ディレクトリ配下の、実行タスク格納ディレクトリ名（Role名）

---

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

---

### group_vars/all.yml
全グループで共通して使用可能な変数を定義するためのファイル（このファイルはPlaybook実行時に自動的に読み込まれる）

ここでは、サーバ（マシン）再起動の待ち時間のみ定義している

```yaml
---
# サーバ再起動待ちのタイムアウト時間 [秒]
## Vagrant環境だと実際には reboot が起こらないため、短めのタイムアウト時間を指定した方が良い
## 通常のサーバであれば、それなりに長いタイムアウト時間を指定する必要がある
reboot_wait_timeout: 10
```

なお、ここでは動作確認にVagrant仮想マシンを使用しているため、reboot コマンドで実際にマシンが再起動することはない

そのため、いつまで待っても再起動が成功することはなく、タイムアウト時間を長めに設定しても意味がない

なお、実際に再起動は起こらないが、マシン再起動を要する設定の反映は問題なく完了するため特に気にする必要はない

---

### main.yml
Playbook実行時のエントリーファイル

`playbooks`ディレクトリ内のRoleごとのPlaybookファイルをimportするだけ

```yaml
---
# 共通セキュリティ基本設定
- import_playbook: playbooks/management.yml
```

---

### playbooks/management.yml
共通セキュリティ設定を定義するPlaybookファイル

```yaml
---
- hosts: web # ホスト名は基本的に web で統一する
  become: true # root権限で実行
  roles:
    - management # ./roles/management/tasks/main.yml を実行
```

---

### playbooks/roles/management/tasks/main.yml
対応するrole名のPlaybookから呼び出される各種タスクを定義するファイル

このファイルではタスクを直接記述せず、関連タスクを別ファイルに記述して include するようにした方が運用しやすい

```yaml
---
# SELinux関連設定
## includeモジュールで 別ファイルの中身をそのまま展開できる
- include: selinux.yml

# 管理者ユーザ設定
- include: admin_users.yml

# 一般ユーザ設定
- include: users.yml

# sshd, iptables設定
- include: services.yml
```

---

## SELinux関連設定
SELinuxを使用するか無効化するかは慎重に検討する必要がある

CentOS 7 ではデフォルトで有効化されているため、極力有効化しておいた方が望ましいが、ここでは `use_selinux`フラグ変数で無効化もできるように設定する

---

### group_vars/management/settings.yml
`group_vars/{グループ名}/`ディレクトリ配下の各設定ファイルは、グループのPlaybook実行時に自動的に読み込まれるため、分かりやすい名前をつけておくと良い

ここでは、`settings.yml`というファイルで SELinux有効／無効のフラグ変数を定義している

```yaml
---
# SELinuxを使うかどうか
## SELinuxがデフォルトで無効になっているOSの場合、true を指定しても有効化したりはしない
## ※必要があれば修正する
use_selinux: true
```

---

### group_vars/management/ports.yml
ポート関連の設定変数を定義している

本番運用の際は、SSH接続ポートをデフォルトの 22番ポートにしておくのは危険だが、設定を失敗するとサーバに対する設定が一切できなくなってしまうため、開発段階では 22番ポートも設定しておくと安全

yamlでは、先頭に `-` をつけることで配列を表現することができるため、有効活用すると良い

- 参考: [YAML Syntax - Ansible Documentation](https://docs.ansible.com/ansible/latest/reference_appendices/YAMLSyntax.html)

---

```yaml
---
# SSH接続ポート
## 推測されにくく、他のアプリケーションポートと重複しないポートを指定する
## 開発段階では、22番を含む複数ポートを指定しておくと安全
ssh_ports:
  - 22
  - 1022

# 外部からのアクセスを許可するポート
accept_ports:
  # httpポート
  - port: 80
    protocol: 'tcp'
  
  # httpsポート
  - port: 443
    protocol: 'tcp'
```

---

### playbooks/roles/management/tasks/selinux.yml
SELinux関連の設定を行うタスクを定義している

```yaml
---
- name: AnsibleのSELinux関連モジュールを使うためのパッケージをインストール
  # yumモジュール｜name=<パッケージ名（リスト指定可）> state=<present|absent> ...
  yum:
    name:
      - libselinux-python
      - policycoreutils-python
    state: present

- name: SELinux｜sshポート開放
  # seportモジュール｜ports=<ポート番号> proto=<tcp|udp> setype=<ポートのSELinuxタイプ> state=<present|absent> ...
  seport:
    # with_items: '配列' で配列を処理できる｜foreach item in 配列
    ## {{変数名}} で変数の展開が可能
    ports: '{{ item }}'
    setype: ssh_port_t
    proto: tcp
    state: present
    reload: yes # 設定反映のためにSELinux再起動
  with_items: '{{ ssh_ports }}'
  when: use_selinux # SELinuxを使う場合

# ... (略) ...

- include: selinux_disabled.yml
  when: not use_selinux # SELinuxを使わない場合
```

---

### playbooks/roles/management/tasks/selinux_disabled.yml
SELinuxを無効化し、サーバマシンを再起動するタスクが定義してある

```yaml
---
# SELinuxが有効化されていると SSHポートの変更等が面倒、という場合は無効化してしまうのも手（セキュリティリスクは慎重に検討すること）
## 参考: http://redj.hatenablog.com/entry/2018/04/22/135933

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

---

## ユーザ管理と sshd, iptables 設定

続いて、運用に工夫が必要なユーザ管理と sshd, iptables の設定を行う

- 参考: [Ansible Playbookでユーザ管理（登録・削除）をまるっとやる](https://tech.smartcamp.co.jp/entry/2019/05/10/215035?utm_source=feed)

sshd, iptables, SELinux はポート制御関連で相互に関わり合っている部分も多いため、なるべく一緒に管理したほうが良い

---

### group_vars/management/users.yml
ユーザの追加・削除をしたい場合は、この変数定義ファイルに設定を記述する

SSH接続してサーバ内の各種操作が可能なユーザは `admin_users`, FTP（SFTP）接続してファイルの更新だけが可能なユーザは `users` に設定する

各ユーザがサーバ接続するための鍵ファイルは `ssh`ディレクトリに生成される

---

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

---

### playbooks/roles/management/tasks/admin_users.yml
管理者ユーザ（SSH接続可・sudo権限あり）の追加・削除を行うタスクを定義している

```yaml
---
# (一部のみ抜粋)

- name: 管理者グループ作成
  # groupモジュール｜name=<グループ名> state=<present（作成）|absent（削除）>
  group: name={{ admin_group }} state=present

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

- name: 管理者ユーザの秘密鍵ダウンロード
  fetch: src=/home/{{ item.name }}/.ssh/id_rsa dest=../ssh/{{ item.name }}-id_rsa flat=yes
  with_items: '{{ admin_users }}'
```

---

### playbooks/roles/management/tasks/users.yml
一般ユーザ（SFTP接続してファイルの更新のみ可）の追加・削除を行うタスクを定義している

`admin_users.yml` と似たような内容のため省略

---

### playbooks/roles/management/tasks/services.yml
sshd と iptables の設定タスクを定義するが、注意点として、CentOS 7 以降は iptables の代わりに firewalld がデフォルトのアクセス制御サービスとなっているため、iptables を使うように設定する

今後は firewalld が主流になっていくと思われるが、現時点ではナレッジが十分に蓄積されていない

---

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
  yum: name=iptables-services state=present

# CentOS 7 以降は iptables の代わりに firewalld がデフォルトになっているため停止する
- name: firewalld停止＆スタートアップ削除
  service: name=firewalld state=stopped enabled=false
  ignore_errors: yes # CentOS 6 なら firewalld は存在しないためエラーは無視

- name: iptables（再）起動＆スタートアップ登録
  service: name=iptables state=restarted enabled=true
```

---

### playbooks/roles/management/templates/sshd_config.j2
sshd設定ファイルの内容をJinja2テンプレートを用いて記述している

Jinja2で使える表記法については、[公式リファレンス](https://jinja.palletsprojects.com/en/2.10.x/templates/)を参照

---

```bash
# （一部設定のみ抜粋）

# rootログイン不可
PermitRootLogin no

# パスワード認証不可｜公開鍵認証のみ許可
PasswordAuthentication no
ChallengeResponseAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile	.ssh/authorized_keys

# sftp で chroot させたい場合は internal-sftp を使う必要あり
Subsystem  sftp  internal-sftp

# sftpのみ許可するユーザグループの設定
## {{変数名}} で変数を展開可能
Match Group {{ user_group }}
    # ログインシェルに internal-sftp を強制
    ## => ssh接続はできず、sftp接続のみ可能になる
    ForceCommand internal-sftp
```

---

### playbooks/roles/management/templates/iptables.j2
iptables の設定をテンプレート化している（省略）

---

## Playbook実行
設定できたら動作確認を行う

```bash
# Playbook実行
$ ansible-playbook -i production.yml main.yml
    :
management  : ok=22  changed=18  unreachable=0  failed=0  skipped=6  rescued=0  ignored=0

## => SELinuxを使う想定で設定しているため、SELinux無効化関連タスクはskipされる
## => ssh/vagrant-admin-id_rsa, vagrant-user-id_rsa が保存されるはず

# 作成された管理者ユーザでSSH接続確認
$ chown 600 ssh/vagrant-admin-id_rsa
$ ssh -i ssh/vagrant-admin-id_rsa vagrant-admin@172.17.8.100
```

---

```bash
## => 問題なく接続できたら、ポートの確認を行う

# iptables の開放ポートを確認
[vagrant-admin ~]$ sudo iptables -nL

# SELinuxを有効化している場合: SELinuxのポリシーを確認
## 普通に semanage を実行すると UnicodeEncodingError が起こるため PYTHONIOENCODING環境変数を設定しながら実行する
[vagrant-admin ~]$ sudo PYTHONIOENCODING=utf-8 python /usr/sbin/semanage port -l

## => iptables, SELinux の開放ポート（特にSSHポート）が想定通り設定されていればOK

# SSH切断
[vagrant-admin ~]$ exit
```

---

```bash
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

なお、ここでは、全部の設定を行ってから動作確認をしているが、本来はもう少し細かい単位の設定ごとに動作確認をしていくほうが安全である

---

## 本Playbookの問題

今回作成したPlaybookには問題が残っており、**SELinux関連の設定のべき等性が担保されていない**

本来は、SELinuxが無効化されている場合に有効化する処理が必要になるため注意が必要である
