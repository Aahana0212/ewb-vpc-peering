#!/usr/bin/env bash
# Workbook page 11 — Controlled failure: remove ONLY App-B's ICMP rule, prove ping stops, restore it.
source "$(dirname "$0")/lib.sh"
need SG_APP_B

ICMP_RULE="[{\"IpProtocol\":\"icmp\",\"FromPort\":8,\"ToPort\":0,\"IpRanges\":[{\"CidrIp\":\"$APP_A_IP/32\"}]}]"

log "Removing App-B inbound ICMP Echo request rule from $APP_A_IP/32 (SSH rule untouched)"
aws_ ec2 revoke-security-group-ingress --group-id "$SG_APP_B" --ip-permissions "$ICMP_RULE" >/dev/null
evidence failure-01-sg-rule-removed.txt "Controlled failure - ewb-sg-app-b inbound rules after removing ICMP" \
  show_sg ewb-sg-app-b "$SG_APP_B"
evidence failure-02-ping-blocked.txt "Controlled failure - App-A pings App-B with ICMP rule removed (expected: no replies)" \
  ssh ewb-app-a "hostname; ping -c 4 -W 2 $APP_B_IP"

log "Restoring the exact rule"
allow_icmp "$SG_APP_B" "$APP_A_IP/32" "App-A echo request"
evidence failure-03-sg-rule-restored.txt "Recovery - ewb-sg-app-b inbound rules after restoring ICMP" \
  show_sg ewb-sg-app-b "$SG_APP_B"
sleep 3
evidence failure-04-ping-recovered.txt "Recovery - App-A pings App-B after restoring the rule (expected: 4 replies)" \
  ssh ewb-app-a "hostname; ping -c 4 $APP_B_IP"
