#!/usr/bin/env bash
# Workbook page 8 — SSH access works, and App-A CANNOT reach App-B before peering.
source "$(dirname "$0")/lib.sh"
need BASTION_ID APP_A_ID

log "SSH to bastion"
evidence 00-ssh-bastion.txt "Laptop -> ewb-bastion (SSH)" \
  ssh -o ConnectTimeout=15 ewb-bastion 'hostname; hostname -I'

log "SSH to App-A through the bastion (VPC A local route)"
evidence 00-ssh-app-a.txt "Laptop -> bastion -> ewb-app-a (ProxyJump)" \
  ssh -o ConnectTimeout=15 ewb-app-a 'hostname; hostname -I'

log "Test 01 — Baseline: App-A -> App-B before peering (expect NO replies)"
evidence test-01-baseline.txt "Test 01 / Baseline - App-A pings App-B before peering (expected: 100% packet loss)" \
  ssh ewb-app-a "hostname; hostname -I; ping -c 4 -W 2 $APP_B_IP"
