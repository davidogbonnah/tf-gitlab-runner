variable "region" {
  description = "AWS region for the runner instance."
  type        = string
  default     = "eu-west-2"
}

variable "environment" {
  description = "The environment for the deployment (e.g., dev, prod)."
  type        = string
  default     = "dev"
}

variable "github_url" {
  description = "Github instance URL used to register the runner."
  type        = string
  default     = "https://github.com"
}

variable "github_org" {
  description = "Github organization name."
  type        = string
  default     = "davidogbonnah"
}

variable "github_repo" {
  description = "Github repository name."
  type        = string
  default     = "opa-policies"
}

variable "registration_token" {
  description = "Github runner registration token."
  type        = string
  sensitive   = true
}

variable "runner_name" {
  description = "Runner name shown in github."
  type        = string
  default     = "vpc-github-runner"
}

variable "runner_version" {
  description = "Runner version"
  type        = string
  default     = "2.332.0"
}

variable "runner_tags" {
  description = "Comma-separated tag list for the runner."
  type        = string
  default     = "vpc,self-hosted"
}

variable "runner_group" {
  description = "Runner group to add this runner to."
  type        = string
  default     = "Default"
}

variable "instance_type" {
  description = "EC2 instance type for the github runner."
  type        = string
  default     = "t3.small"
}

variable "subnet_id" {
  description = "Optional subnet override for the runner (use a public subnet for direct SSH)."
  type        = string
  default     = null
}

variable "associate_public_ip" {
  description = "Whether to associate a public IP with the runner instance."
  type        = bool
  default     = false
}

variable "ssh_key_name" {
  description = "Optional EC2 key pair name for SSH access."
  type        = string
  default     = null
}

variable "enable_ssm_endpoints" {
  description = "Create VPC interface endpoints for SSM (required if private subnets have no NAT)."
  type        = bool
  default     = false
}

variable "ssm_endpoint_private_dns_enabled" {
  description = "Enable private DNS for the SSM interface endpoints."
  type        = bool
  default     = true
}

variable "ssm_endpoint_subnet_ids" {
  description = "Optional subnet IDs for SSM VPC interface endpoints."
  type        = list(string)
  default     = null
}

variable "public_access_cidr_blocks" {
  description = "CIDR blocks allowed to SSH to the runner."
  type        = list(string)
  default     = ["208.127.48.163/32", "2.126.128.119/32", "79.77.218.85/32"]
}

variable "root_volume_size" {
  description = "Root volume size in GiB."
  type        = number
  default     = 30
}

variable "root_volume_type" {
  description = "Root volume type."
  type        = string
  default     = "gp3"
}
