#!/bin/bash

###############################################################################
# キーペアの作成
###############################################################################

# キー作成
mkdir -p ~/.ssh
chmod 700 ~/.ssh
aws ec2 create-key-pair --key-name "bastion-key" \
                        --query "KeyMaterial" \
                        --output "text" > ~/.ssh/bastion-key.pem
chmod 600 ~/.ssh/bastion-key.pem

# キー作成
mkdir -p ~/.ssh
chmod 700 ~/.ssh
aws ec2 create-key-pair --key-name "web-key" \
                        --query "KeyMaterial" \
                        --output "text" > ~/.ssh/web-key.pem
chmod 600 ~/.ssh/web-key.pem


###############################################################################
# 踏み台サーバーの作成
###############################################################################

# パブリックサブネットにEC2インスタンスの作成
bastionInstance=`aws ec2 run-instances --image-id "ami-0af1df87db7b650f4" \
                                       --count "1" \
                                       --instance-type "t2.micro" \
                                       --key-name "bastion-key" \
                                       --security-group-ids "${bastionSecurityGroupId}" \
                                       --subnet-id "${publicSubnetAId}" \
                                       --private-ip-address "10.0.1.10"`

# インスタンスIDの抽出
bastionInstanceId=`echo $bastionInstance | jq -r .Instances[].InstanceId`

# 名前の設定
aws ec2 create-tags --resources "${bastionInstanceId}" \
                    --tags Key="Name",Value="bastion-server"

# Elastic IP新しいアドレスの割り当て
bastionElasticIp=`aws ec2 allocate-address --domain "vpc"`

# allocation-idの抽出
bastionAllocationId=`echo "${bastionElasticIp}" | jq -r .AllocationId`

# public-ipの抽出
bastionPublicIp=`echo "${bastionElasticIp}" | jq -r .PublicIp`

# インスタンスがrunning状態になるのを待つ
count=0
while :
do
  bastionInstanceState=`aws ec2 describe-instances --instance-id "${bastionInstanceId}" | jq -r .Reservations[].Instances[].State.Name`
  # ステータスを確認
  if [ "${bastionInstanceState}" = "running" ]; then
    break
  fi
  count=$((++count))
  # 試行回数の確認
  if [ $count -gt 60 ]; then
    echo "running状態を確認できませんでした。"
    exit 1
  fi
done

# EC2インスタンスにElasticIPを紐付け
aws ec2 associate-address --allocation-id "${bastionAllocationId}" \
                          --instance "${bastionInstanceId}" > /dev/null

echo "bastion-serverが作成されました。"


###############################################################################
# Webサーバーの作成
###############################################################################

#
# Web Server A
#

# プライベートサブネットにEC2インスタンスの作成
webInstanceA=`aws ec2 run-instances --image-id "ami-0af1df87db7b650f4" \
                                   --count "1" \
                                   --instance-type "t2.micro" \
                                   --key-name "web-key" \
                                   --security-group-ids "${webSecurityGroupId}" \
                                   --subnet-id "${privateSubnetAId}" \
                                   --private-ip-address "10.0.2.10"`

# インスタンスIDの抽出
webInstanceAId=`echo $webInstanceA | jq -r .Instances[].InstanceId`

# 名前の設定
aws ec2 create-tags --resources "${webInstanceAId}" \
                    --tags Key="Name",Value="web-server-a"

# インスタンスがrunning状態になるのを待つ
count=0
while :
do
  webInstanceAState=`aws ec2 describe-instances --instance-id "${webInstanceAId}" | jq -r .Reservations[].Instances[].State.Name`
  # ステータスを確認
  if [ "${webInstanceAState}" = "running" ]; then
    break
  fi
  count=$((++count))
  # 試行回数の確認
  if [ $count -gt 60 ]; then
    echo "running状態を確認できませんでした。"
    exit 1
  fi
done

echo "web-server-aが作成されました。"

#
# Web Server B
#
# プライベートサブネットにEC2インスタンスの作成
webInstanceB=`aws ec2 run-instances --image-id "ami-0af1df87db7b650f4" \
                                    --count "1" \
                                    --instance-type "t2.micro" \
                                    --key-name "web-key" \
                                    --security-group-ids "${webSecurityGroupId}" \
                                    --subnet-id "${privateSubnetBId}" \
                                    --private-ip-address "10.0.4.10"`

# インスタンスIDの抽出
webInstanceBId=`echo $webInstanceB | jq -r .Instances[].InstanceId`

# 名前の設定
aws ec2 create-tags --resources "${webInstanceBId}" \
                    --tags Key="Name",Value="web-server-b"

# インスタンスがrunning状態になるのを待つ
count=0
while :
do
  webInstanceBState=`aws ec2 describe-instances --instance-id "${webInstanceBId}" | jq -r .Reservations[].Instances[].State.Name`
  # ステータスを確認
  if [ "${webInstanceBState}" = "running" ]; then
    break
  fi
  count=$((++count))
  # 試行回数の確認
  if [ $count -gt 60 ]; then
    echo "running状態を確認できませんでした。"
    exit 1
  fi
done

echo "web-server-bが作成されました。"


###############################################################################
# DBサーバーの作成
###############################################################################

# プライベートサブネットにRDSインスタンスの作成
dbInstance=`aws rds create-db-instance --db-instance-identifier "db-server-a" \
                                       --db-instance-class "db.t2.micro" \
                                       --engine "MySQL" \
                                       --allocated-storage "20" \
                                       --master-username "admin" \
                                       --master-user-password "test#Admin01" \
                                       --vpc-security-group-ids "${dbSecurityGroupId}" \
                                       --db-subnet-group-name "${dbSubnetGroupName}"`

echo "db-server-aが作成されました。"
