#!/usr/bin/env bash
# Workbook page 6 — Build VPC B and set the security group rules
source "$(dirname "$0")/lib.sh"
check_student
need AZ VPC_A_ID

log "VPC B ($VPC_B_CIDR) — no internet gateway"
save VPC_B_ID "$(aws_ ec2 create-vpc --cidr-block "$VPC_B_CIDR" \
  --tag-specifications "$(tags ewb-vpc-b vpc)" --query Vpc.VpcId --output text)"
aws_ ec2 wait vpc-available --vpc-ids "$VPC_B_ID"

save SUBNET_B_PRIVATE "$(aws_ ec2 create-subnet --vpc-id "$VPC_B_ID" --cidr-block "$B_PRIVATE_CIDR" \
  --availability-zone "$AZ" --tag-specifications "$(tags ewb-b-private subnet)" \
  --query Subnet.SubnetId --output text)"

save RT_B_PRIVATE "$(aws_ ec2 create-route-table --vpc-id "$VPC_B_ID" \
  --tag-specifications "$(tags ewb-rt-b-private route-table)" \
  --query RouteTable.RouteTableId --output text)"
aws_ ec2 associate-route-table --route-table-id "$RT_B_PRIVATE" --subnet-id "$SUBNET_B_PRIVATE" >/dev/null
ok "ewb-b-private explicitly associated; local route only"

log "Detecting your laptop's public IPv4"
if [ -z "$MY_IP_CIDR" ]; then
  MY_IP=$(curl -fsS https://checkip.amazonaws.com | tr -d '[:space:]') || die "Could not detect public IP; set MY_IP_CIDR in config.env"
  MY_IP_CIDR="$MY_IP/32"
fi
save MY_IP_CIDR "$MY_IP_CIDR"

log "Security groups"
mk_sg() { # NAME VPC DESCRIPTION
  aws_ ec2 create-security-group --group-name "$1" --vpc-id "$2" --description "$3" \
    --tag-specifications "$(tags "$1" security-group)" --query GroupId --output text
}
save SG_BASTION "$(mk_sg ewb-sg-bastion "$VPC_A_ID" 'EWB bastion - SSH from student laptop only')"
save SG_APP_A   "$(mk_sg ewb-sg-app-a   "$VPC_A_ID" 'EWB App-A - SSH from bastion, ICMP from App-B')"
save SG_APP_B   "$(mk_sg ewb-sg-app-b   "$VPC_B_ID" 'EWB App-B - SSH from bastion, ICMP from App-A')"

log "Inbound rules (workbook table, page 6)"
allow_ssh  "$SG_BASTION" "$MY_IP_CIDR"     "Student laptop public IPv4"
allow_ssh  "$SG_APP_A"   "$BASTION_IP/32"  "Bastion private IP"
allow_icmp "$SG_APP_A"   "$APP_B_IP/32"    "App-B echo request"
allow_ssh  "$SG_APP_B"   "$BASTION_IP/32"  "Bastion private IP (ProxyJump)"
allow_icmp "$SG_APP_B"   "$APP_A_IP/32"    "App-A echo request"
# Default outbound allow-all rules and default network ACLs are left unchanged.

all_sgs() {
  show_sg ewb-sg-bastion "$SG_BASTION"
  show_sg ewb-sg-app-a   "$SG_APP_A"
  show_sg ewb-sg-app-b   "$SG_APP_B"
}
evidence security-groups-inbound.txt "Inbound rules for each security group" all_sgs
