#!/usr/bin/env bash
# Workbook page 14 — Clean up in dependency order, then verify nothing is left.
# Every delete is best-effort so a rerun finishes whatever an earlier run missed.
source "$(dirname "$0")/lib.sh"

try() { "$@" >/dev/null 2>&1 && ok "$*" || warn "skipped: ${*:3:2}"; }

echo "This permanently deletes every EWB lab resource in $AWS_REGION."
read -r -p "Have you saved your evidence? Type DELETE to continue: " answer
[ "$answer" = "DELETE" ] || die "Cancelled"

log "Step 1 — Terminate instances"
IDS=$(aws_ ec2 describe-instances --filters Name=tag:Project,Values="$PROJECT_TAG" \
  Name=instance-state-name,Values=pending,running,stopping,stopped \
  --query 'Reservations[].Instances[].InstanceId' --output text)
if [ -n "$IDS" ]; then
  # shellcheck disable=SC2086
  aws_ ec2 terminate-instances --instance-ids $IDS >/dev/null
  # shellcheck disable=SC2086
  aws_ ec2 wait instance-terminated --instance-ids $IDS
  ok "Terminated: $IDS"
fi

log "Step 2 — Peering routes and peering connection"
[ -n "${RT_A_PRIVATE:-}" ] && try aws_ ec2 delete-route --route-table-id "$RT_A_PRIVATE" --destination-cidr-block "$VPC_B_CIDR"
[ -n "${RT_B_PRIVATE:-}" ] && try aws_ ec2 delete-route --route-table-id "$RT_B_PRIVATE" --destination-cidr-block "$VPC_A_CIDR"
[ -n "${RT_A_PUBLIC:-}" ]  && try aws_ ec2 delete-route --route-table-id "$RT_A_PUBLIC"  --destination-cidr-block "$VPC_B_CIDR"
[ -n "${PCX_ID:-}" ]       && try aws_ ec2 delete-vpc-peering-connection --vpc-peering-connection-id "$PCX_ID"

log "Step 3 — Security groups (instance network interfaces are gone now)"
for sg in "${SG_APP_A:-}" "${SG_APP_B:-}" "${SG_BASTION:-}"; do
  [ -n "$sg" ] && try aws_ ec2 delete-security-group --group-id "$sg"
done

log "Step 4 — Subnets, then custom route tables"
for s in "${SUBNET_A_PUBLIC:-}" "${SUBNET_A_PRIVATE:-}" "${SUBNET_B_PRIVATE:-}"; do
  [ -n "$s" ] && try aws_ ec2 delete-subnet --subnet-id "$s"
done
for rt in "${RT_A_PUBLIC:-}" "${RT_A_PRIVATE:-}" "${RT_B_PRIVATE:-}"; do
  [ -n "$rt" ] && try aws_ ec2 delete-route-table --route-table-id "$rt"
done

log "Step 5 — Internet gateway and VPCs"
if [ -n "${IGW_A_ID:-}" ]; then
  try aws_ ec2 detach-internet-gateway --internet-gateway-id "$IGW_A_ID" --vpc-id "${VPC_A_ID:-}"
  try aws_ ec2 delete-internet-gateway --internet-gateway-id "$IGW_A_ID"
fi
for v in "${VPC_A_ID:-}" "${VPC_B_ID:-}"; do
  [ -n "$v" ] && try aws_ ec2 delete-vpc --vpc-id "$v"
done

log "Step 6 — Key pair"
try aws_ ec2 delete-key-pair --key-name "$KEY_NAME"
read -r -p "Also delete the local key $KEY_FILE? [y/N] " k
if [ "$k" = "y" ]; then rm -f "$KEY_FILE"; ok "Local key removed"; fi

log "Step 7 — Verify the account is clear (filtered by Project tag)"
verify() {
  echo "Instances not terminated:"
  aws_ ec2 describe-instances --filters Name=tag:Project,Values="$PROJECT_TAG" \
    Name=instance-state-name,Values=pending,running,stopping,stopped \
    --query 'Reservations[].Instances[].InstanceId' --output text
  echo "Volumes:";        aws_ ec2 describe-volumes --filters Name=tag:Project,Values="$PROJECT_TAG" --query 'Volumes[].VolumeId' --output text
  echo "Elastic IPs:";    aws_ ec2 describe-addresses --filters Name=tag:Project,Values="$PROJECT_TAG" --query 'Addresses[].PublicIp' --output text
  echo "VPCs:";           aws_ ec2 describe-vpcs --filters Name=tag:Project,Values="$PROJECT_TAG" --query 'Vpcs[].VpcId' --output text
  echo "Peering (not deleted):"
  aws_ ec2 describe-vpc-peering-connections --filters Name=tag:Project,Values="$PROJECT_TAG" \
    --query 'VpcPeeringConnections[?Status.Code!=`deleted`].VpcPeeringConnectionId' --output text
  echo "Key pair:";       aws_ ec2 describe-key-pairs --filters Name=key-name,Values="$KEY_NAME" --query 'KeyPairs[].KeyName' --output text
  echo "(Empty lists above = clean. Also check Billing; usage reporting can lag.)"
}
evidence cleanup-verification.txt "Cleanup evidence - remaining lab resources (all lists should be empty)" verify

mv "$STATE_FILE" "$STATE_FILE.deleted" 2>/dev/null || true
