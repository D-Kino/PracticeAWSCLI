#!/bin/bash

# エラー時処理を止める
set -e

# 実行スクリプトディレクトリに移動
cd `dirname $0`

# ネットワーク構築
. ./aws_network.sh
echo "ネットワークが構築されました。"

# サーバー構築
. ./aws_server.sh
echo "サーバーが構築されました。"

# ロードバランサー構築
. ./aws_loadbalancer.sh
echo "ロードバランサーが構築されました。"

# ロードバランサー構築
. ./aws_natgateway.sh
echo "NATゲートウェイが構築されました。"

# Ansible SSH多段認証設定ファイルの作成
sed -e "s/%bastionPublicIp%/${bastionPublicIp}/g" ./ansible/vars_template.yml \
  | sed -e "s/%privateKey%/web-key.pem/g" > ./ansible/inventory/group_vars/WebServer.yml

sed -e "s/%bastionPublicIp%/${bastionPublicIp}/g" ./ansible/vars_template.yml \
  | sed -e "s/%privateKey%/bastion-key.pem/g" > ./ansible/inventory/group_vars/BastionServer.yml
