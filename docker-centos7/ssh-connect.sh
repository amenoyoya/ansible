#!/bin/bash

# コンテナを作り直すたびに known_hosts の設定をクリアするのは面倒であるため
# KnownHostsFile=/dev/null, StrictHostKeyChecking=no でssh接続
ssh -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no $@
