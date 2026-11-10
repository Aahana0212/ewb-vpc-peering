#!/usr/bin/env bash
# Workbook page 7 — Key pair and the three instances with fixed private IPs
source "$(dirname "$0")/lib.sh"
check_student
need SUBNET_A_PUBLIC SUBNET_A_PRIVATE SUBNET_B_PRIVATE SG_BASTION SG_APP_A SG_APP_B

log "Step 1 — RSA key pair '$KEY_NAME' (private key stays on this laptop)"
mkdir -p "$(dirname "$KEY_FILE")" && chmod 700 "$(dirname "$KEY_FILE")"
if aws_ ec2 describe-key-pairs --key-names "$KEY_NAME" >/dev/null 2>&1; then
  [ -f "$KEY_FILE" ] || die "Key pair $KEY_NAME exists in AWS but $KEY_FILE is missing. Delete the key pair and rerun."
  warn "Key pair already exists; reusing $KEY_FILE"
else
  aws_ ec2 create-key-pair --key-name "$KEY_NAME" --key-type rsa --key-format pem \
    --tag-specifications "$(tags "$KEY_NAME" key-pair)" \
    --query KeyMaterial --output text > "$KEY_FILE"
  chmod 400 "$KEY_FILE"
  ok "Saved $KEY_FILE (chmod 400)"
fi

log "Step 2 — Latest Amazon Linux 2023 (x86_64) AMI"
AMI_ID=$(aws_ ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query Parameter.Value --output text 2>/dev/null || true)
if [ -z "$AMI_ID" ] || [ "$AMI_ID" = "None" ]; then
  AMI_ID=$(aws_ ec2 describe-images --owners amazon \
    --filters 'Name=name,Values=al2023-ami-2023.*-kernel-*-x86_64' Name=state,Values=available \
    --query 'sort_by(Images,&CreationDate)[-1].ImageId' --output text)
fi
save AMI_ID "$AMI_ID"

launch() { # NAME SUBNET PRIVATE_IP SG PUBLIC(true|false)
  aws_ ec2 run-instances --image-id "$AMI_ID" --instance-type "$INSTANCE_TYPE" --key-name "$KEY_NAME" \
    --network-interfaces "[{\"DeviceIndex\":0,\"SubnetId\":\"$2\",\"PrivateIpAddress\":\"$3\",\"Groups\":[\"$4\"],\"AssociatePublicIpAddress\":$5,\"DeleteOnTermination\":true}]" \
    --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeSize":8,"VolumeType":"gp3","DeleteOnTermination":true}}]' \
    --metadata-options HttpTokens=required \
    --tag-specifications "$(tags "$1" instance volume)" \
    --query 'Instances[0].InstanceId' --output text
}

log "Launching instances"
save BASTION_ID "$(launch ewb-bastion "$SUBNET_A_PUBLIC"  "$BASTION_IP" "$SG_BASTION" true)"
save APP_A_ID   "$(launch ewb-app-a   "$SUBNET_A_PRIVATE" "$APP_A_IP"   "$SG_APP_A"   false)"
save APP_B_ID   "$(launch ewb-app-b   "$SUBNET_B_PRIVATE" "$APP_B_IP"   "$SG_APP_B"   false)"

log "Waiting for all three to pass status checks (2-4 minutes)"
aws_ ec2 wait instance-status-ok --instance-ids "$BASTION_ID" "$APP_A_ID" "$APP_B_ID"
ok "All instances running and healthy"

save BASTION_PUBLIC_IP "$(instance_field "$BASTION_ID" PublicIpAddress)"

inventory() {
  aws_ ec2 describe-instances --instance-ids "$BASTION_ID" "$APP_A_ID" "$APP_B_ID" --query \
    'Reservations[].Instances[].{Name:Tags[?Key==`Name`]|[0].Value, InstanceId:InstanceId, PrivateIp:PrivateIpAddress, PublicIp:PublicIpAddress, Subnet:SubnetId, State:State.Name}' \
    --output table
}
evidence checkpoint-02-instances.txt "Checkpoint 02 - Instance IDs, private IPs, public IPv4 (None expected for App-A and App-B)" inventory

"$(dirname "$0")/write-ssh-config.sh"
