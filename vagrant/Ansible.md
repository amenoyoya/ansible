# Ansibleによる構成管理

## Vagrant仮想サーバ準備

Vagarantとは、VirtualBox等のホスト型仮想環境の構築・設定を支援する自動化ツールである

まずは、本物のサーバをいじる前に、VirtualBox＋Vagrantで作成した仮想サーバを用いてAnsibleの動作確認を行っていく

### VirtualBox, Vagrantのインストール

#### on Windows 10
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

#### on Ubuntu 18.04
```bash
# virtualbox. vagrant インストール
$ sudo apt install -y virtualbox
$ sudo apt install -y virtualbox-ext-pack
$ sudo apt install -y vagrant

# vagrantプラグイン インストール
$ vagrant plugin install vagrant-vbguest # VagrantのゲストOS-カーネル間のバージョン不一致解決用プラグイン
```

### CentOS7 仮想マシン構築
Vagrantは `Vagrantfile` に仮想マシン設定を記述して `vagrant up` コマンドを叩くだけで仮想マシンを自動的に構築することができる

ここでは CentOS7 仮想マシンを構築するため、`Vagrantfile`を以下のように記述する

```ruby
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "centos/7" # CentOS7 のBoxファイルを使う
  config.vbguest.auto_update = false # host-guest間の差分アップデートを無効化

  # Create a private network, which allows host-only access to the machine using a specific IP.
  ## ここで設定したIPアドレスを介して仮想マシンにSSH接続できる
  ## 複数の仮想マシンを作成する場合は、ホスト部（100）を重複しない値に設定する（101〜）
  config.vm.network "private_network", ip: "172.17.8.100"
end
```

記述したら、Vagrantfileのあるディレクトリで以下のコマンドを実行し仮想マシンを起動する

```bash
# Vagrantfile設定に従って仮想マシン起動
## 初回起動時はBoxファイル（仮想OSのイメージファイル）ダウンロードに時間がかかる
$ vagrant up

# なお、仮想マシンを終了する場合は halt コマンドを実行する
# $ vagrant halt
```

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

***

## Ansibleを使ってみる

### インベントリファイルの作成
Ansibleの接続先サーバ情報等を記述した設定ファイルを**インベントリファイル**と呼ぶ

インベントリファイル名は任意だが、ここでは `servers.yml` というファイル名にする

なお、インベントリファイルの形式としては**ini形式**と**yaml形式**があるが、ここではyaml形式を採用する

`servers.yml` にサーバ情報を以下の通り記述する（yaml形式ではインデントにも意味があるため、インデント幅に注意すること）

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

意味としては以下のようになる

- hosts設定:
    - サーバIPアドレス `172.17.8.100` を `vagrant` というエイリアス名に設定
- vars設定: ここではSSH接続情報を記述
    - `ansible_ssh_port`: SSH接続ポート｜基本的に`22`を指定
    - `ansible_ssh_user`: SSH接続ユーザ
    - `ansible_ssh_private_key_file`: SSH接続用秘密鍵のパス
        - 鍵ファイルではなくパスワードで接続する場合は `ansible_ssh_pass` を指定する
    - `ansible_sudo_pass`: rootユーザパスワード｜rootユーザでSSH接続する場合は `ansible_ssh_pass` と同一になる

### 単一コマンドの実行
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
