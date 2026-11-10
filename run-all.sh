#!/usr/bin/env bash
# Builds and tests the whole lab in workbook order. Cleanup is separate on purpose.
set -euo pipefail
cd "$(dirname "$0")/scripts"

./01-create-vpc-a.sh
./02-create-vpc-b-and-security.sh
./03-launch-instances.sh
./04-baseline-test.sh
echo -e "\nBaseline captured. Take your console screenshots for checkpoints 01-02 now if needed."
read -r -p "Press Enter to create the peering connection..."
./05-create-peering.sh
./06-add-routes.sh
./07-verify.sh
./08-controlled-failure.sh
./09-inventory.sh

echo -e "\nAll done. Evidence is in ./evidence. When your report is finished, run: ./scripts/10-cleanup.sh"
