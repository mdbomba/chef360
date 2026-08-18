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
