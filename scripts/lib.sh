#!/usr/bin/env bash
# Shared settings and helpers sourced by every step script.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT_DIR/config.env"

STATE_FILE="$ROOT_DIR/.lab-state.env"   # resource IDs created so far (git-ignored)
EVIDENCE_DIR="$ROOT_DIR/evidence"
mkdir -p "$EVIDENCE_DIR"
# shellcheck source=/dev/null
[ -f "$STATE_FILE" ] && source "$STATE_FILE"

export AWS_DEFAULT_REGION="$AWS_REGION"
export AWS_PAGER=""

aws_() { aws --region "$AWS_REGION" "$@"; }
log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()   { printf '    \033[32m✔ %s\033[0m\n' "$*"; }
warn() { printf '    \033[33m! %s\033[0m\n' "$*"; }
die()  { printf '\033[31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

# save KEY VALUE  -> stores a resource ID in the state file and the current shell
save() {
  local k=$1 v=$2
  [ -n "$v" ] && [ "$v" != "None" ] || die "Empty value for $k"
  if [ -f "$STATE_FILE" ]; then
    grep -v "^$k=" "$STATE_FILE" > "$STATE_FILE.tmp" || true
    mv "$STATE_FILE.tmp" "$STATE_FILE"
  fi
  echo "$k=$v" >> "$STATE_FILE"
  printf -v "$k" '%s' "$v"
  ok "$k = $v"
}

# need VAR...  -> stop if an earlier step has not produced the value
need() {
  local v
  for v in "$@"; do
    [ -n "${!v:-}" ] || die "Missing $v. Run the earlier step scripts first."
  done
}

check_student() {
  [ "$STUDENT_NAME" != "Your Name" ] || die "Set STUDENT_NAME in config.env first."
  command -v aws >/dev/null || die "AWS CLI v2 is not installed."
  aws_ sts get-caller-identity >/dev/null || die "AWS CLI is not logged in (run: aws configure)."
}

# tags NAME TYPE [TYPE...] -> JSON tag specification with Name, Project and Student
tags() {
  local name=$1 out="" t; shift
  for t in "$@"; do
    out="$out{\"ResourceType\":\"$t\",\"Tags\":[{\"Key\":\"Name\",\"Value\":\"$name\"},{\"Key\":\"Project\",\"Value\":\"$PROJECT_TAG\"},{\"Key\":\"Student\",\"Value\":\"$STUDENT_NAME\"}]},"
  done
  printf '[%s]' "${out%,}"
}

# evidence FILE "TITLE" command...  -> runs a command and saves labelled output
evidence() {
  local file="$EVIDENCE_DIR/$1" title=$2; shift 2
  {
    echo "### $title"
    echo "# Run at: $(date '+%Y-%m-%d %H:%M:%S %Z') | Region: $AWS_REGION | Student: $STUDENT_NAME"
    echo "\$ $*"
    "$@" 2>&1 || echo "[command exited with status $?]"
    echo
  } | tee "$file"
}

# Inbound rule helpers (ICMP Echo request = type 8, code 0)
allow_ssh() {   # GROUP_ID CIDR DESCRIPTION
  aws_ ec2 authorize-security-group-ingress --group-id "$1" --ip-permissions \
    "[{\"IpProtocol\":\"tcp\",\"FromPort\":22,\"ToPort\":22,\"IpRanges\":[{\"CidrIp\":\"$2\",\"Description\":\"$3\"}]}]" >/dev/null
  ok "SSH 22 from $2 -> $1"
}
allow_icmp() {  # GROUP_ID CIDR DESCRIPTION
  aws_ ec2 authorize-security-group-ingress --group-id "$1" --ip-permissions \
    "[{\"IpProtocol\":\"icmp\",\"FromPort\":8,\"ToPort\":0,\"IpRanges\":[{\"CidrIp\":\"$2\",\"Description\":\"$3\"}]}]" >/dev/null
  ok "ICMP echo request from $2 -> $1"
}

# show_rt NAME ID -> routes and subnet associations of one route table
show_rt() {
  echo "Route table: $1 ($2)"
  aws_ ec2 describe-route-tables --route-table-ids "$2" --query \
    'RouteTables[0].{SubnetAssociations:Associations[?SubnetId].SubnetId, Routes:Routes[].{Destination:DestinationCidrBlock, Target:GatewayId || VpcPeeringConnectionId, State:State}}' \
    --output yaml
}

# show_sg NAME ID -> inbound rules of one security group
show_sg() {
  echo "Security group: $1 ($2)"
  aws_ ec2 describe-security-group-rules --filters Name=group-id,Values="$2" --query \
    'SecurityGroupRules[?IsEgress==`false`].{Protocol:IpProtocol, From:FromPort, To:ToPort, Source:CidrIpv4, Note:Description}' \
    --output table
}

# instance_field INSTANCE_ID JMESPATH
instance_field() {
  aws_ ec2 describe-instances --instance-ids "$1" --query "Reservations[0].Instances[0].$2" --output text
}

pcx_status() {
  aws_ ec2 describe-vpc-peering-connections --vpc-peering-connection-ids "$1" \
    --query 'VpcPeeringConnections[0].Status.Code' --output text
}
