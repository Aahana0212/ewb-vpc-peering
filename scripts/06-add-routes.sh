#!/usr/bin/env bash
# Workbook page 10 — Add routes on both sides (forward path + return path)
source "$(dirname "$0")/lib.sh"
need PCX_ID RT_A_PRIVATE RT_B_PRIVATE RT_A_PUBLIC

add_route() { # RT_ID DEST WHY
  aws_ ec2 create-route --route-table-id "$1" --destination-cidr-block "$2" \
    --vpc-peering-connection-id "$PCX_ID" >/dev/null
  ok "$2 -> $PCX_ID on $1 ($3)"
}

log "Adding peering routes"
add_route "$RT_A_PRIVATE" "$VPC_B_CIDR" "App-A to VPC B"
add_route "$RT_B_PRIVATE" "$VPC_A_CIDR" "Return path to VPC A"
add_route "$RT_A_PUBLIC"  "$VPC_B_CIDR" "Bastion SSH to App-B"

all_rts() {
  show_rt ewb-rt-a-private "$RT_A_PRIVATE"
  show_rt ewb-rt-b-private "$RT_B_PRIVATE"
  show_rt ewb-rt-a-public  "$RT_A_PUBLIC"
}
evidence checkpoint-04-route-tables.txt "Checkpoint 04 - Routes and subnet associations for all three route tables" all_rts
