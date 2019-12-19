# Ansibleインストール方法

## Dockerを使ったインストール方法

```bash
# GitHubからDockerCompose構成ファイルダウンロード
$ wget -O - https://github.com/amenoyoya/ansible/releases/download/0.1.0/docker-ansible.tar.gz | tar xzvf -

# プロジェクトディレクトリに移動
$ cd docker-ansible

# docker-compose run でコンテナ実行（--rm: 実行完了したらコンテナ削除）
# ※ 初回起動時のみイメージのPull＆Buildに時間かかる

## 例: ansible バージョン確認
$ docker-compose run --rm ansible --version

## 例: ansible-playbook 実行
$ docker-compose run --rm ansible-playbook -i inventoryfile playbookfile.yml
```

***

## Dockerを使わないAnsibleインストール方法

Ansibleはローカルマシンにインストールする必要がある

ここでは、Windows 10 環境と Ubuntu 18.04 環境におけるインストール方法を公開する

### Ansibleインストール on Windows 10
Ansibleは残念ながらWindows非対応である

そのためここでは、Windows Subsystem Linux（WSL）を使うことにする

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

### Ansibleインストール on Ubuntu 18.04
```bash
# Ansibleインストール用のリポジトリ追加
$ sudo apt update && sudo apt install software-properties-common
$ sudo apt-add-repository --yes --update ppa:ansible/ansible

# Ansibleインストール
$ sudo apt install ansible

# バージョン確認
$ ansible --version
ansible 2.9.1
```
