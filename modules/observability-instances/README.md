# observability-instances

## Purpose

Deploys four small Amazon Linux 2023 EC2 instances in public subnets for a Grafana sandbox: **grafana**, **prometheus**, **database** and **alloy** (Alloy gateway). The instances are bare: no user_data, no software. Each has a single encrypted gp3 disk (the root volume, 30 GiB by default) and a public IP. Security groups pre-open the expected ports (Grafana 3000, Prometheus 9090, PostgreSQL 5432, Alloy 4317/4318/12345). Security groups only allow traffic from the VPC CIDR (and between the instances), so the public IPs are not reachable from the internet until you add rules; SSM Session Manager works out of the box. Each instance has its own ED25519 key pair; the private key is stored in Secrets Manager (`<name_prefix>/<role>/ssh-private-key`). Port 22 is not opened in the security groups; tunnel SSH through SSM Session Manager or add a rule.

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5 |
| aws | ~> 5.0 |
| tls | ~> 4.0 |

Nothing is installed on the instances; software is installed manually after deployment. The public subnets reach the internet through the internet gateway for that.

## Usage

```hcl
module "observability" {
  source = "../../modules/observability-instances"

  customer     = "dnx"
  environment  = "labs"
  owner        = "alexandre.alvao@dnx.solutions"
  vpc_id       = "vpc-0123456789abcdef0"
  vpc_cidr     = "172.16.0.0/16"
  subnet_ids   = ["subnet-a", "subnet-b", "subnet-c"]
  subnet_cidrs = ["172.16.0.0/20", "172.16.16.0/20", "172.16.32.0/20"]
}
```

Connect with `aws ssm start-session --target <instance_id>`; the `grafana_port_forward_command` output forwards port 3000 once Grafana is installed.

## Inputs

| Name | Type | Description | Default | Required |
|------|------|-------------|---------|----------|
| customer | string | Customer short name | n/a | yes |
| environment | string | Environment name | n/a | yes |
| owner | string | Owner tag value | n/a | yes |
| vpc_id | string | VPC ID | n/a | yes |
| vpc_cidr | string | VPC CIDR; may reach Grafana and Alloy | n/a | yes |
| subnet_ids | list(string) | Public subnet IDs | n/a | yes |
| subnet_cidrs | list(string) | CIDRs of `subnet_ids`, same order | n/a | yes |
| service | string | Service name in the naming pattern | `"observability"` | no |
| name_prefix | string | Prefix for all resource names | `null` (`{customer}-{environment}-{service}`) | no |
| instance_type | string | Instance type for all instances | `"t3.small"` | no |
| root_volume_size | number | Size of the single (root) disk in GiB | `30` | no |
| secret_recovery_window_in_days | number | Recovery window for the SSH key secrets | `7` | no |
| tags | map(string) | Extra tags | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| instance_ids | Instance IDs by role |
| private_ips | Fixed private IPs by role |
| public_ips | Public IPs by role |
| security_group_ids | Security group IDs by role |
| ssh_private_key_secret_arns | Secrets Manager ARNs of the SSH private keys by role |
| grafana_port_forward_command | SSM port-forward command for the Grafana UI |
