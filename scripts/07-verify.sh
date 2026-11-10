#!/usr/bin/env bash
# Workbook page 11 — Prove the project works (tests 02-05)
source "$(dirname "$0")/lib.sh"
need APP_A_ID APP_B_ID

log "Test 02 — Forward path: App-A -> App-B (expect 4 replies, 0% loss)"
evidence test-02-forward-path.txt "Test 02 / Forward path - App-A pings App-B over the peering connection" \
  ssh ewb-app-a "hostname; hostname -I; ping -c 4 $APP_B_IP"

log "Test 03 — Reverse path: App-B -> App-A (expect 4 replies, 0% loss)"
evidence test-03-reverse-path.txt "Test 03 / Reverse path - App-B pings App-A over the peering connection" \
  ssh ewb-app-b "hostname; hostname -I; ping -c 4 $APP_A_IP"

log "Test 04 — Private SSH: laptop -> bastion -> App-B"
evidence test-04-private-ssh-app-b.txt "Test 04 / Private SSH - shell on App-B through the bastion" \
  ssh ewb-app-b 'echo "Connected to: $(hostname)"; hostname -I; whoami; echo "SSH client seen by App-B: $SSH_CLIENT"'

log "Test 05 — Isolation: no public IPv4 on App-A or App-B"
isolation() {
  aws_ ec2 describe-instances --instance-ids "$APP_A_ID" "$APP_B_ID" --query \
    'Reservations[].Instances[].{Name:Tags[?Key==`Name`]|[0].Value, PrivateIp:PrivateIpAddress, PublicIpv4:PublicIpAddress || `none`}' \
    --output table
}
evidence test-05-isolation.txt "Test 05 / Isolation - App-A and App-B have no public IPv4" isolation
