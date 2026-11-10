#!/usr/bin/env bash
# Workbook page 8 — Writes the ProxyJump entries into ~/.ssh/config.
# Rerun this any time the bastion's public IPv4 changes (e.g. after a stop/start).
source "$(dirname "$0")/lib.sh"
need BASTION_ID

BASTION_PUBLIC_IP=$(instance_field "$BASTION_ID" PublicIpAddress)
[ "$BASTION_PUBLIC_IP" != "None" ] || die "Bastion has no public IPv4"
save BASTION_PUBLIC_IP "$BASTION_PUBLIC_IP"

SSH_CONFIG="$HOME/.ssh/config"
BEGIN="# >>> ewb-vpc-peering >>>"
END="# <<< ewb-vpc-peering <<<"
touch "$SSH_CONFIG" && chmod 600 "$SSH_CONFIG"
cp "$SSH_CONFIG" "$SSH_CONFIG.bak.ewb"

# Remove any previous block from this project, keep everything else
awk -v b="$BEGIN" -v e="$END" '$0==b{skip=1} !skip{print} $0==e{skip=0}' "$SSH_CONFIG.bak.ewb" > "$SSH_CONFIG"

cat >> "$SSH_CONFIG" <<EOF
$BEGIN
# Lab hosts use their own known_hosts file so reused lab IPs never clash
# with your other servers. accept-new trusts a host only on first contact.
Host ewb-bastion
    HostName $BASTION_PUBLIC_IP
    User ec2-user
    IdentityFile $KEY_FILE
    IdentitiesOnly yes
    UserKnownHostsFile ~/.ssh/ewb-known_hosts
    StrictHostKeyChecking accept-new

Host ewb-app-a
    HostName $APP_A_IP
    User ec2-user
    IdentityFile $KEY_FILE
    IdentitiesOnly yes
    ProxyJump ewb-bastion
    UserKnownHostsFile ~/.ssh/ewb-known_hosts
    StrictHostKeyChecking accept-new

Host ewb-app-b
    HostName $APP_B_IP
    User ec2-user
    IdentityFile $KEY_FILE
    IdentitiesOnly yes
    ProxyJump ewb-bastion
    UserKnownHostsFile ~/.ssh/ewb-known_hosts
    StrictHostKeyChecking accept-new
$END
EOF
ok "$SSH_CONFIG updated (backup: $SSH_CONFIG.bak.ewb). Bastion: $BASTION_PUBLIC_IP"
