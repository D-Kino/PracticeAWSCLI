#!/bin/bash

###############################################################################
# NATゲートウェイの作成
###############################################################################

# Elastic IP新しいアドレスの割り当て
elasticIp=`aws ec2 allocate-address --domain "vpc"`

# allocation-idの抽出
allocationId=`echo "${elasticIp}" | jq -r .AllocationId`

# パブリックサブネットにNATゲートウェイの作成
natGateway=`aws ec2 create-nat-gateway --subnet-id "${publicSubnetAId}" \
                                       --allocation-id "${allocationId}"`

# NATゲートウェイIDの抽出
natGatewayId=`echo "${natGateway}" | jq -r .NatGateway.NatGatewayId`

# 名前の設定
aws ec2 create-tags --resources "${natGatewayId}" \
                    --tags Key="Name",Value="nat-gateway"

# メインルートテーブルの取得
mainRouteTable=`aws ec2 describe-route-tables --filter Name="association.main",Values="true"`

# メインルートテーブルIDの抽出
mainRouteTableId=`echo "${mainRouteTable}" | jq -r .RouteTables[].RouteTableId`

# ルーティング準備状態を確認
# available状態となったらルーティング可能とする
count=0
# 一時的にエラー停止を止める
set +e
while :
do
  sleep 1s
  # メインルートテーブルにNATゲートウェイのルートを追加
  aws ec2 create-route --destination-cidr-block "0.0.0.0/0" \
                       --route-table-id "${mainRouteTableId}" \
                       --nat-gateway-id "${natGatewayId}" > /dev/null 2>&1
  # 終了ステータスコードの確認
  if [ ${?} -eq 0 ]; then
    break
  fi
  count=$((++count))
  # 試行回数の確認
  if [ $count -gt 60 ]; then
    echo "ルートの追加に失敗しました。"
    exit 1
  fi
done
set -e

echo "nat-gatewayが作成されました。"
