#!/bin/bash

###############################################################################
# アプリケーションロードバランサーの構築
###############################################################################

# アプリケーションロードバランサーの作成
loadBalancer=`aws elbv2 create-load-balancer --name "elbv2-load-balancer" \
                                             --subnets $publicSubnetAId $publicSubnetBId \
                                             --security-groups "${loadBalancerSecurityGroupId}"`

echo "elbv2-load-balancerが作成されました。"

# LoadBalancerArn
loadBalancerArn=`echo $loadBalancer | jq -r .LoadBalancers[].LoadBalancerArn`

# ターゲットグループの作成
targetGroup=`aws elbv2 create-target-group --name "targets" \
                                           --protocol "HTTP" \
                                           --port "80" \
                                           --vpc-id "${vpcId}"`

# TargetGroupArnの抽出
targetGroupArn=`echo $targetGroup | jq -r .TargetGroups[].TargetGroupArn`

# ターゲットグループへインスタンスを登録
aws elbv2 register-targets --target-group-arn "${targetGroupArn}" \
                           --targets Id="${webInstanceAId}",Port="80"


aws elbv2 register-targets --target-group-arn "${targetGroupArn}" \
                           --targets Id="${webInstanceBId}",Port="80"

# リスナーの作成
listener=`aws elbv2 create-listener --load-balancer-arn "${loadBalancerArn}" \
                                    --protocol "HTTP" \
                                    --port "80" \
                                    --default-actions Type=forward,TargetGroupArn="${targetGroupArn}"`
