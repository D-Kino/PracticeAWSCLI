#!/bin/bash

###############################################################################
# VPCの作成
###############################################################################

# VPCの作成
vpc=`aws ec2 create-vpc --region "ap-northeast-1" \
                        --cidr-block "10.0.0.0/16"`

# VPCIDの抽出
vpcId=`echo "${vpc}" | jq -r .Vpc.VpcId`

# VPCに名前の設定
aws ec2 create-tags --resources "${vpcId}" \
                    --tags Key="Name",Value="vpc"

echo "vpcが作成されました。"

###############################################################################
# サブネットの作成（パブリック）
###############################################################################

# サブネットの作成
publicSubnetA=`aws ec2 create-subnet --vpc-id "${vpcId}" \
                                     --cidr-block "10.0.1.0/24" \
                                     --availability-zone "ap-northeast-1a"`

# サブネットIDの抽出
publicSubnetAId=`echo "${publicSubnetA}" | jq -r .Subnet.SubnetId`

# 名前の設定
aws ec2 create-tags --resources "${publicSubnetAId}" \
                    --tags Key="Name",Value="public-subnet-a"

echo "public-subnet-aが作成されました。"

# サブネットの作成（ALBがMultiAZが必須なため作成する）
publicSubnetB=`aws ec2 create-subnet --vpc-id "${vpcId}" \
                                     --cidr-block "10.0.3.0/24" \
                                     --availability-zone "ap-northeast-1c"`

# サブネットIDの抽出
publicSubnetBId=`echo "${publicSubnetB}" | jq -r .Subnet.SubnetId`

# 名前の設定
aws ec2 create-tags --resources "${publicSubnetBId}" \
                    --tags Key="Name",Value="public-subnet-b"

echo "public-subnet-bが作成されました。"


###############################################################################
# サブネットの作成（プライベート）
###############################################################################

# サブネットの作成
privateSubnetA=`aws ec2 create-subnet --vpc-id "${vpcId}" \
                                      --cidr-block "10.0.2.0/24" \
                                      --availability-zone "ap-northeast-1a"`

# サブネットIDの抽出
privateSubnetAId=`echo "${privateSubnetA}" | jq -r .Subnet.SubnetId`

# 名前の設定
aws ec2 create-tags --resources "${privateSubnetAId}" \
                    --tags Key="Name",Value="private-subnet-a"

echo "private-subnet-aが作成されました。"

# サブネットの作成
privateSubnetB=`aws ec2 create-subnet --vpc-id "${vpcId}" \
                                      --cidr-block "10.0.4.0/24" \
                                      --availability-zone "ap-northeast-1c"`

# サブネットIDの抽出
privateSubnetBId=`echo "${privateSubnetB}" | jq -r .Subnet.SubnetId`

# 名前の設定
aws ec2 create-tags --resources "${privateSubnetBId}" \
                    --tags Key="Name",Value="private-subnet-b"

echo "private-subnet-bが作成されました。"


###############################################################################
# サブネットグループの作成（プライベート）
###############################################################################

# DBサブネットグループの作成
dbSubnetGroupName="db-private-subnet"
aws rds create-db-subnet-group --db-subnet-group-name "${dbSubnetGroupName}" \
                               --db-subnet-group-description "DB Private Subnet Group" \
                               --subnet-ids "${privateSubnetAId}" "${privateSubnetBId}" > /dev/null

echo "db-private-subnetが作成されました。"

###############################################################################
# インターネットゲートウェイの作成
###############################################################################

# インターネットゲートウェイの作成
igw=`aws ec2 create-internet-gateway`

# インターネットゲートウェイIDの抽出
igwId=`echo "${igw}" | jq -r .InternetGateway.InternetGatewayId`

# 名前の設定
aws ec2 create-tags --resources "${igwId}" \
                    --tags Key="Name",Value="internet-gateway"

# VPCにインターネットゲートウェイをアタッチ
aws ec2 attach-internet-gateway --vpc-id "${vpcId}" \
                                --internet-gateway-id "${igwId}"

echo "internet-gatewayが作成されました。"

###############################################################################
# カスタムルートテーブルの作成
###############################################################################

# ルートテーブルの作成
publicRouteTable=`aws ec2 create-route-table --vpc-id "${vpcId}"`

# ルートテーブルIDの作成
publicRouteTableId=`echo "${publicRouteTable}" | jq -r .RouteTable.RouteTableId`

# 名前の設定
aws ec2 create-tags --resources "${publicRouteTableId}" \
                    --tags Key="Name",Value="public-route-table"

# インターネットゲートウェイへのすべてのトラフィック (0.0.0.0/0) をポイントするルートテーブルでルートを作成
aws ec2 create-route --route-table-id "${publicRouteTableId}" \
                     --destination-cidr-block "0.0.0.0/0" \
                     --gateway-id "${igwId}" > /dev/null

# ルートテーブル サブネットの関連付け
aws ec2 associate-route-table  --subnet-id "${publicSubnetAId}" \
                               --route-table-id "${publicRouteTableId}" > /dev/null

echo "public-route-tableが作成されました。"


###############################################################################
# セキュリティグループの作成
###############################################################################

# bastion-server
# セキュリティグループの作成
bastionSecurityGroup=`aws ec2 create-security-group --group-name "ssh-group" \
                                                    --description "SSH Security Group" \
                                                    --vpc-id "${vpcId}"`

# グループIDの抽出
bastionSecurityGroupId=`echo "${bastionSecurityGroup}" | jq -r .GroupId`

# ルールの追加
aws ec2 authorize-security-group-ingress --group-id "${bastionSecurityGroupId}" \
                                         --protocol "tcp" \
                                         --port "22" \
                                         --cidr "0.0.0.0/0"

# load-balancer
# セキュリティグループの作成
loadBalancerSecurityGroup=`aws ec2 create-security-group --group-name "load-balancer-group" \
                                                         --description "SSH Security Group" \
                                                         --vpc-id "${vpcId}"`

# グループIDの抽出
loadBalancerSecurityGroupId=`echo "${loadBalancerSecurityGroup}" | jq -r .GroupId`

# ルールの追加
aws ec2 authorize-security-group-ingress --group-id "${loadBalancerSecurityGroupId}" \
                                         --protocol "tcp" \
                                         --port "80" \
                                         --cidr "0.0.0.0/0"

# web-server
# セキュリティグループの作成
webSecurityGroup=`aws ec2 create-security-group --group-name "web-server-group" \
                                                --description "Web Server security group" \
                                                --vpc-id "${vpcId}"`

# グループIDの抽出
webSecurityGroupId=`echo "${webSecurityGroup}" | jq -r .GroupId`

# ルールの追加
aws ec2 authorize-security-group-ingress --group-id "${webSecurityGroupId}" \
                                         --protocol "tcp" \
                                         --port "22" \
                                         --source-group "${bastionSecurityGroupId}" > /dev/null

aws ec2 authorize-security-group-ingress --group-id "${webSecurityGroupId}" \
                                         --protocol "tcp" \
                                         --port "80" \
                                         --source-group "${loadBalancerSecurityGroupId}" > /dev/null

# db-server
# セキュリティグループの作成
dbSecurityGroup=`aws ec2 create-security-group --group-name "db-server-group" \
                                               --description "DB Server security group" \
                                               --vpc-id "${vpcId}"`

# グループIDの抽出
dbSecurityGroupId=`echo "${dbSecurityGroup}" | jq -r .GroupId`

# ルールの追加
aws ec2 authorize-security-group-ingress --group-id "${dbSecurityGroupId}" \
                                         --protocol "tcp" \
                                         --port "3306" \
                                         --source-group "${bastionSecurityGroupId}" > /dev/null

aws ec2 authorize-security-group-ingress --group-id "${dbSecurityGroupId}" \
                                         --protocol "tcp" \
                                         --port "3306" \
                                         --source-group "${webSecurityGroupId}" > /dev/null

echo "セキュリティグループが作成されました。"
