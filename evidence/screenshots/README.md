# Evidence

The scripts write labelled terminal output here when you run them against your own AWS account.
Each file records the command, the time it ran, the Region and the student name.

| File | Proves | Workbook item |
|---|---|---|
| `checkpoint-01-vpc-a-routes.txt` | Public/private subnet associations, public default route | Checkpoint 01 |
| `security-groups-inbound.txt` | Inbound rules of all three security groups | Page 6 / checklist 4 |
| `checkpoint-02-instances.txt` | Instance IDs, private IPs, bastion public IPv4 | Checkpoint 02 |
| `00-ssh-bastion.txt`, `00-ssh-app-a.txt` | SSH works before peering | Page 8 |
| `test-01-baseline.txt` | App-A cannot reach App-B before peering | Test 01 |
| `checkpoint-03-peering.txt` | Peering name, Active status, both VPC IDs | Checkpoint 03 |
| `checkpoint-04-route-tables.txt` | All three route tables with peering routes | Checkpoint 04 |
| `test-02-forward-path.txt` | App-A → App-B, 4 replies | Test 02 |
| `test-03-reverse-path.txt` | App-B → App-A, 4 replies | Test 03 |
| `test-04-private-ssh-app-b.txt` | Shell on App-B through the bastion | Test 04 |
| `test-05-isolation.txt` | No public IPv4 on App-A / App-B | Test 05 |
| `failure-01..04-*.txt` | ICMP rule removed → ping fails → restored → ping recovers | Controlled failure |
| `inventory.txt` | Every resource with its real ID | Checklist 2 |
| `cleanup-verification.txt` | Nothing left in the account | Checklist 7 |

Console screenshots (peering Active, route tables, instance details) go in `evidence/screenshots/`.
