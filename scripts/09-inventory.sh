#!/usr/bin/env bash
# Resource inventory with real IDs for the report (checklist item 2).
source "$(dirname "$0")/lib.sh"
need VPC_A_ID VPC_B_ID

full_inventory() {
  echo "Region: $AWS_REGION   AZ: ${AZ:-}"
  echo
  echo "VPCs";            aws_ ec2 describe-vpcs --vpc-ids "$VPC_A_ID" "$VPC_B_ID" \
    --query 'Vpcs[].{Name:Tags[?Key==`Name`]|[0].Value, VpcId:VpcId, Cidr:CidrBlock}' --output table
  echo "Subnets";         aws_ ec2 describe-subnets --filters Name=vpc-id,Values="$VPC_A_ID","$VPC_B_ID" \
    --query 'Subnets[].{Name:Tags[?Key==`Name`]|[0].Value, SubnetId:SubnetId, Cidr:CidrBlock, AZ:AvailabilityZone, AutoPublicIp:MapPublicIpOnLaunch}' --output table
  echo "Route tables";    aws_ ec2 describe-route-tables --filters Name=tag:Project,Values="$PROJECT_TAG" \
    --query 'RouteTables[].{Name:Tags[?Key==`Name`]|[0].Value, Id:RouteTableId, Vpc:VpcId}' --output table
  echo "Internet gateway"; aws_ ec2 describe-internet-gateways --internet-gateway-ids "$IGW_A_ID" \
    --query 'InternetGateways[].{Name:Tags[?Key==`Name`]|[0].Value, Id:InternetGatewayId, AttachedTo:Attachments[0].VpcId}' --output table
  echo "Security groups"; aws_ ec2 describe-security-groups --group-ids "$SG_BASTION" "$SG_APP_A" "$SG_APP_B" \
    --query 'SecurityGroups[].{Name:GroupName, Id:GroupId, Vpc:VpcId}' --output table
  echo "Instances";       aws_ ec2 describe-instances --filters Name=tag:Project,Values="$PROJECT_TAG" Name=instance-state-name,Values=running \
    --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`]|[0].Value, Id:InstanceId, Type:InstanceType, PrivateIp:PrivateIpAddress, PublicIp:PublicIpAddress}' --output table
  echo "Peering";         aws_ ec2 describe-vpc-peering-connections --vpc-peering-connection-ids "$PCX_ID" \
    --query 'VpcPeeringConnections[].{Id:VpcPeeringConnectionId, Status:Status.Code}' --output table
}
evidence inventory.txt "Resource inventory with actual IDs" full_inventory
