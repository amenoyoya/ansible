# Docker/Ansible環境

- 参考: [ansible in dockerお試しメモ](https://qiita.com/m0559reen/items/d593c526af64c29293f5)

## 構成

```bash
docker-ansible/
 |_ ssh/ # SSH鍵や接続設定等を格納（docker://ansible:/root/.ssh/ にマウント）
 |_ Dockerfile # AlpineLinux + Ansible環境構築ファイル
 |_ docker-compose.yml # ansibleコンテナ: ansibleコマンドとして利用
                       # ansible-playbookコンテナ: ansible-playbookコマンドとして利用
```

***

## 使い方

docker-compose.yml には `ansible`, `ansible-playbook` コンテナが定義されており、各コンテナはコマンドとして利用することを想定している

そのため、利用時にコンテナを起動 => コマンド実行完了したらコンテナ削除 という運用を推奨

```bash
# docker-compose run でコンテナ実行（--rm: 実行完了したらコンテナ削除）
# ※ 初回起動時のみイメージのPull＆Buildに時間かかる

## 例: ansible バージョン確認
$ docker-compose run --rm ansible --version

## 例: ansible-playbook 実行
$ docker-compose run --rm ansible-playbook -i inventoryfile playbookfile.yml
```
