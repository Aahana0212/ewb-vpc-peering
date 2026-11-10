#!/usr/bin/env bash
# Workbook page 9 — Request, accept and activate the peering connection
source "$(dirname "$0")/lib.sh"
check_student
need VPC_A_ID VPC_B_ID

log "Step 1 — Peering request (requester ewb-vpc-a -> accepter ewb-vpc-b, same account and Region)"
save PCX_ID "$(aws_ ec2 create-vpc-peering-connection --vpc-id "$VPC_A_ID" --peer-vpc-id "$VPC_B_ID" \
  --tag-specifications "$(tags ewb-a-b-peer vpc-peering-connection)" \
  --query VpcPeeringConnection.VpcPeeringConnectionId --output text)"
aws_ ec2 wait vpc-peering-connection-exists --vpc-peering-connection-ids "$PCX_ID"

log "Step 2 — Accept the request (required even within one account)"
for _ in $(seq 1 40); do
  s=$(pcx_status "$PCX_ID")
  case "$s" in
    pending-acceptance) aws_ ec2 accept-vpc-peering-connection --vpc-peering-connection-id "$PCX_ID" >/dev/null
                        ok "Request accepted"; break ;;
    active)             break ;;
    failed|rejected)    die "Peering is $s — check both VPC CIDRs for overlap" ;;
  esac
  sleep 3
done

log "Step 3 — Wait for Active"
for _ in $(seq 1 40); do
  s=$(pcx_status "$PCX_ID"); [ "$s" = "active" ] && break; sleep 3
done
[ "$(pcx_status "$PCX_ID")" = "active" ] || die "Peering did not become active"
ok "$PCX_ID is Active"

peering() {
  aws_ ec2 describe-vpc-peering-connections --vpc-peering-connection-ids "$PCX_ID" --query \
    'VpcPeeringConnections[0].{Name:Tags[?Key==`Name`]|[0].Value, Id:VpcPeeringConnectionId, Status:Status.Code, RequesterVpc:RequesterVpcInfo.VpcId, RequesterCidr:RequesterVpcInfo.CidrBlock, AccepterVpc:AccepterVpcInfo.VpcId, AccepterCidr:AccepterVpcInfo.CidrBlock}' \
    --output table
}
evidence checkpoint-03-peering.txt "Checkpoint 03 - Peering connection name, Active status and both VPC IDs" peering
