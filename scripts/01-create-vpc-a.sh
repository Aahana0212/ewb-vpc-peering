#!/usr/bin/env bash
# Workbook page 5 — Create VPC A (VPC, 2 subnets, IGW, public + private route tables)
source "$(dirname "$0")/lib.sh"
check_student

log "Choosing an Availability Zone that offers $INSTANCE_TYPE"
AZ=$(aws_ ec2 describe-instance-type-offerings --location-type availability-zone \
  --filters Name=instance-type,Values="$INSTANCE_TYPE" \
  --query 'sort_by(InstanceTypeOfferings,&Location)[0].Location' --output text)
save AZ "$AZ"

log "Step 1 — VPC A ($VPC_A_CIDR)"
save VPC_A_ID "$(aws_ ec2 create-vpc --cidr-block "$VPC_A_CIDR" \
  --tag-specifications "$(tags ewb-vpc-a vpc)" --query Vpc.VpcId --output text)"
aws_ ec2 wait vpc-available --vpc-ids "$VPC_A_ID"

log "Step 2 — Subnets in $AZ"
save SUBNET_A_PUBLIC "$(aws_ ec2 create-subnet --vpc-id "$VPC_A_ID" --cidr-block "$A_PUBLIC_CIDR" \
  --availability-zone "$AZ" --tag-specifications "$(tags ewb-a-public subnet)" \
  --query Subnet.SubnetId --output text)"
save SUBNET_A_PRIVATE "$(aws_ ec2 create-subnet --vpc-id "$VPC_A_ID" --cidr-block "$A_PRIVATE_CIDR" \
  --availability-zone "$AZ" --tag-specifications "$(tags ewb-a-private subnet)" \
  --query Subnet.SubnetId --output text)"
# Auto-assign public IPv4 stays disabled on both subnets (AWS default for custom subnets).
# Only the bastion gets a public IP, requested explicitly at launch.

log "Step 3 — Internet gateway"
save IGW_A_ID "$(aws_ ec2 create-internet-gateway \
  --tag-specifications "$(tags ewb-igw-a internet-gateway)" \
  --query InternetGateway.InternetGatewayId --output text)"
aws_ ec2 attach-internet-gateway --internet-gateway-id "$IGW_A_ID" --vpc-id "$VPC_A_ID"
ok "ewb-igw-a attached to ewb-vpc-a"

log "Step 4 — Public route table (0.0.0.0/0 -> IGW)"
save RT_A_PUBLIC "$(aws_ ec2 create-route-table --vpc-id "$VPC_A_ID" \
  --tag-specifications "$(tags ewb-rt-a-public route-table)" \
  --query RouteTable.RouteTableId --output text)"
aws_ ec2 associate-route-table --route-table-id "$RT_A_PUBLIC" --subnet-id "$SUBNET_A_PUBLIC" >/dev/null
aws_ ec2 create-route --route-table-id "$RT_A_PUBLIC" \
  --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_A_ID" >/dev/null
ok "ewb-a-public explicitly associated; default route added"

log "Step 5 — Private route table (local route only)"
save RT_A_PRIVATE "$(aws_ ec2 create-route-table --vpc-id "$VPC_A_ID" \
  --tag-specifications "$(tags ewb-rt-a-private route-table)" \
  --query RouteTable.RouteTableId --output text)"
aws_ ec2 associate-route-table --route-table-id "$RT_A_PRIVATE" --subnet-id "$SUBNET_A_PRIVATE" >/dev/null
ok "ewb-a-private explicitly associated; no internet route"

log "Checkpoint 01 evidence"
checkpoint_01() {
  show_rt ewb-rt-a-public "$RT_A_PUBLIC"
  show_rt ewb-rt-a-private "$RT_A_PRIVATE"
}
evidence checkpoint-01-vpc-a-routes.txt "Checkpoint 01 - VPC A route tables and associations" checkpoint_01
