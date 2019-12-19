# LAMP環境の構築

## Playbook構成

`lamp`というRoleで構築していく

```bash
./
|_ production.yml
|_ main.yml
|_ group_vars/
|   |_ all.yml
|   |_ users.yml # ユーザ管理用設定ファイル
|   |_ ports.yml # ポート設定等の変数定義ファイル
|   |_ version.yml # 使用するソフトウェアバージョン定義ファイル
|
|_ playbooks/
|   |_ management.yml # 共通セキュリティ設定Playbook
|   |_ lamp.yml # LAMP環境構築Playbook
|   |_ roles/
|       |_ management/
|       |   |_ tasks/
|       |   |   |_ main.yml
|       |   |   |_ selinux_disabled.yml
|       |   |   |_ admin_users.yml
|       |   |   |_ users.yml
|       |   |   |_ services.yml
|       |   |
|       |   |_ templates/
|       |       |_ sshd_config.j2
|       |       |_ iptables.j2
|       |
|       |_ lamp/ # LAMP環境構築Role
|           |_ tasks/
|           |   |_ main.yml
|           |
|           |_ templates/
|
|_ ssh/
```

