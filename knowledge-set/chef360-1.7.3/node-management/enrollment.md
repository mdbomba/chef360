# Node Enrollment

Node enrollment brings nodes under Chef 360 Platform management.

## Enrollment Methods

### Self Enrollment
- Node initiates enrollment using an application key
- Application keys generated via API or CLI
- Troubleshooting available for enrollment issues

### Bulk Enrollment
- Enroll multiple nodes simultaneously
- CSV or JSON file-based enrollment

### Cookbook Enrollment
- Use Chef Infra Client cookbook to enroll nodes
- Leverages existing Chef infrastructure

### Single-Node Enrollment
- Enroll individual nodes via CLI or API

The management workstation can initiate SSH or WinRM enrollment through
`chef-node-management-cli enrollment enroll-node`. For Linux SSH enrollment,
the request identifies the cohort, node address, protocol, and credential:

```bash
chef-node-management-cli enrollment enroll-node \
  --body-file <PROTECTED_REQUEST_FILE> \
  --body-format json \
  --profile <PROFILE_NAME>
```

The request file contains a password or private key and must be protected and
removed immediately after use. The repository wrapper
`scripts/chef360/enroll-node-linux-cli.sh` builds a temporary request, checks
for an existing node, and avoids duplicate enrollment.

For node-side enrollment, install `chef-node-enrollment-cli` on the target and
use a protected signed configuration generated for the Chef 360 environment:

```bash
sudo chef-node-enrollment-cli enroll-node \
  --cohortId <COHORT_ID> \
  --sign-config-file <SIGNED_CONFIG_FILE>
```

Signed configurations are credentials and must remain outside source control.

### Enrollment Status and Approval

Controller-initiated enrollment returns an enrollment ID. Query it, then query
the resulting node status:

```bash
chef-node-management-cli status get-enrollmentId-status \
  --enrollmentId <ENROLLMENT_ID> --profile <PROFILE_NAME>
chef-node-management-cli status get-status \
  --nodeId <NODE_ID> --profile <PROFILE_NAME>
```

When the assigned cohort requires approval, review the admitted node before
running:

```bash
chef-node-management-cli management node approve-node \
  --nodeId <NODE_ID> --profile <PROFILE_NAME>
```

## Enrollment Process
1. Node communicates with Chef 360 Platform
2. Platform credentials and communication mechanism (WinRM/SSH) required
3. Node Management and Courier agents installed
4. Skills installed on nodes
5. Monitoring begins for jobs and check-ins

## Node Enrollment Service
- Enrolls new nodes
- Retrieves enrollment status
- Updates enrollment status
- Interacts with Chef Database (infrastructure)
