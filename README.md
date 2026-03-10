# tf-gitlab-runner

[![Build and Push OPA Bundle](https://github.com/davidogbonnah/opa-policies/actions/workflows/opa-bundle.yml/badge.svg)](https://github.com/davidogbonnah/opa-policies/actions/workflows/opa-bundle.yml)

Provision a self-hosted GitHub Actions runner on AWS using Terraform. The runner is launched as an EC2 instance inside your VPC, registered to a GitHub org/repo, and can be managed via AWS Systems Manager (SSM).

## What this creates
- EC2 instance running Amazon Linux and the GitHub Actions runner
- Security group for the runner (optional SSH ingress, open egress)
- IAM role + instance profile with `AmazonSSMManagedInstanceCore`
- Optional VPC interface endpoints for SSM services

## Prerequisites
- Terraform >= 1.11.0
- AWS account and credentials with permissions to create EC2, IAM, and VPC endpoints
- An existing VPC state file in S3 that exposes `vpc_id` and `private_subnet_ids`
- A GitHub Actions runner registration token for your org/repo

## Inputs
| Variable | Description | Type | Default |
| --- | --- | --- | --- |
| `region` | AWS region for the runner instance | string | `eu-west-2` |
| `environment` | Environment tag (e.g., dev, prod) | string | `dev` |
| `github_url` | GitHub instance URL | string | `https://github.com` |
| `github_org` | GitHub organization | string | `dogb-capco` |
| `github_repo` | GitHub repository | string | `opa-policies` |
| `registration_token` | GitHub runner registration token | string | **required** |
| `runner_name` | Runner name | string | `vpc-github-runner` |
| `runner_version` | Runner version | string | `2.331.0` |
| `runner_tags` | Comma-separated runner labels | string | `vpc,self-hosted` |
| `runner_group` | Runner group | string | `Default` |
| `instance_type` | EC2 instance type | string | `t3.small` |
| `subnet_id` | Subnet override (use public for SSH) | string | `null` |
| `associate_public_ip` | Associate a public IP | bool | `false` |
| `ssh_key_name` | EC2 key pair name for SSH | string | `null` |
| `enable_ssm_endpoints` | Create SSM VPC endpoints | bool | `false` |
| `ssm_endpoint_private_dns_enabled` | Enable SSM private DNS | bool | `true` |
| `ssm_endpoint_subnet_ids` | Subnet IDs for SSM endpoints | list(string) | `null` |
| `ssh_ingress_cidr_blocks` | Allowed SSH CIDRs | list(string) | `[]` |
| `root_volume_size` | Root volume size (GiB) | number | `30` |
| `root_volume_type` | Root volume type | string | `gp3` |

## Outputs
- `instance_id`
- `private_ip`
- `public_ip`
- `security_group_id`

## Usage
1) Update `backend.tf` for your S3 state bucket/key if needed.  
2) Update `data.terraform_remote_state.vpc` in `data.tf` to point at your VPC state.  
3) Run Terraform:

```bash
terraform init
terraform plan -var 'registration_token=YOUR_TOKEN'
terraform apply -var 'registration_token=YOUR_TOKEN'
```

## GitHub Actions workflows
This repo includes two workflows:
- **Terraform Deploy** (`.github/workflows/terraform-deploy.yml`): runs security scans, `terraform plan`, and applies on `main` when there are changes.
- **Terraform Auto Destroy** (`.github/workflows/terraform-auto-destroy.yml`): runs daily and destroys the stack if there has been no successful apply in the last 72 hours.

Required secrets:
- `RUNNER_TOKEN` for the GitHub runner registration token (used during plan/apply)

## Notes and tips
- If the runner is in private subnets without NAT, enable `enable_ssm_endpoints` so the instance can register and be managed via SSM.
- For SSH access, set `associate_public_ip=true`, `subnet_id` to a public subnet, and add CIDRs to `ssh_ingress_cidr_blocks`.
- Registration tokens are short-lived; rotate them when applying.

## Cleanup
```bash
terraform destroy -var 'registration_token=YOUR_TOKEN'
```
