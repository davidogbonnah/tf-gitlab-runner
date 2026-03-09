# This data source retrieves the VPC information from the remote state of the VPC module.
# It allows you to reference the VPC ID and other related information in your ECS task definition.
# The VPC module is assumed to be in a different directory and managed separately.
data "terraform_remote_state" "vpc" {
  backend = "s3"

  config = {
    bucket = "dcopro-tfstate"
    key    = "dev/platform/vpc/terraform.tfstate"
    region = "eu-west-2"
  }
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-*-x86_64*"]
  }
}
