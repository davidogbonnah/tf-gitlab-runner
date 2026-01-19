locals {
  tags = {
    Environment  = var.environment
    Project      = "ACME Cloud Management Platform"
    Owner        = "UK Technology"
    ManagedBy    = "Terraform"
    ContactEmail = "david.ogbonnah@acme.com"
  }
  ssm_endpoint_services = [
    "ssm",
    "ec2messages",
    "ssmmessages",
  ]
}

resource "aws_security_group" "github_runner" {
  name        = "${var.runner_name}-sg"
  description = "Security group for Github runner instance"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id
  tags        = local.tags
}

resource "aws_security_group_rule" "ssh_ingress" {
  for_each          = toset(var.public_access_cidr_blocks)
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.github_runner.id
  cidr_blocks       = [each.value]
  description       = "Allow SSH access to runner"
}

resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.github_runner.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow outbound traffic"
}

resource "aws_security_group" "ssm_vpc_endpoints" {
  count       = var.enable_ssm_endpoints ? 1 : 0
  name        = "${var.runner_name}-ssm-endpoints-sg"
  description = "Security group for SSM VPC interface endpoints"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id
  tags        = local.tags
}

resource "aws_security_group_rule" "ssm_endpoints_https_ingress" {
  count                    = var.enable_ssm_endpoints ? 1 : 0
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ssm_vpc_endpoints[0].id
  source_security_group_id = aws_security_group.github_runner.id
  description              = "Allow HTTPS from runner to SSM endpoints"
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = data.terraform_remote_state.vpc.outputs.vpc_id
  for_each            = var.enable_ssm_endpoints ? toset(local.ssm_endpoint_services) : toset([])
  service_name        = "com.amazonaws.${var.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = var.ssm_endpoint_private_dns_enabled
  security_group_ids  = [aws_security_group.ssm_vpc_endpoints[0].id]
  subnet_ids          = var.ssm_endpoint_subnet_ids != null ? var.ssm_endpoint_subnet_ids : data.terraform_remote_state.vpc.outputs.private_subnet_ids

  tags = merge(
    local.tags,
    {
      Name = "${var.runner_name}-${each.value}-endpoint"
    }
  )
}


resource "aws_iam_role" "github_runner" {
  name = "${var.runner_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.github_runner.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "github_runner" {
  name = "${var.runner_name}-profile"
  role = aws_iam_role.github_runner.name
}

resource "aws_instance" "github_runner" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = var.instance_type
  subnet_id                   = coalesce(var.subnet_id, data.terraform_remote_state.vpc.outputs.private_subnet_ids[0])
  vpc_security_group_ids      = [aws_security_group.github_runner.id]
  associate_public_ip_address = var.associate_public_ip
  key_name                    = var.ssh_key_name

  iam_instance_profile = aws_iam_instance_profile.github_runner.name

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = var.root_volume_type
  }

  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail

    if command -v dnf >/dev/null 2>&1; then
      PKG=dnf
    else
      PKG=yum
    fi

    $PKG -y install \
      libicu icu \
      openssl-libs \
      krb5-libs \
      libstdc++ \
      libgcc \
      tar \
      gzip \
      file \
      shadow-utils \
      amazon-ssm-agent \
      git \
      zlib

    dnf -y swap curl-minimal curl-full
    systemctl enable --now amazon-ssm-agent

    RUNNER_USER="actions"
    id -u "$${RUNNER_USER}" >/dev/null 2>&1 || useradd --create-home --shell /bin/bash "$${RUNNER_USER}"

    mkdir -p /opt/actions-runner
    cd /opt/actions-runner

    ARCH="$(uname -m)"
    case "$ARCH" in
      x86_64) RUNNER_ARCH="x64" ;;
      aarch64) RUNNER_ARCH="arm64" ;;
      *) echo "Unsupported arch: $ARCH" >&2; exit 1 ;;
    esac

    RUNNER_VERSION="${var.runner_version}"
    RUNNER_TGZ="actions-runner-linux-$${RUNNER_ARCH}-$${RUNNER_VERSION}.tar.gz"
    RUNNER_URL="https://github.com/actions/runner/releases/download/v$${RUNNER_VERSION}/$${RUNNER_TGZ}"

    curl -fL --retry 5 --retry-delay 2 -o "$${RUNNER_TGZ}" "$${RUNNER_URL}"
    tar -xzf "$${RUNNER_TGZ}"


    # Register runner
    chown -R "$${RUNNER_USER}:$${RUNNER_USER}" /opt/actions-runner

    sudo -u "$${RUNNER_USER}" ./config.sh \
      --unattended \
      --url "${var.github_url}/${var.github_org}/${var.github_repo}" \
      --token "${var.registration_token}" \
      --name "${var.runner_name}" \
      --labels "${var.runner_tags}" \
      --runnergroup "${var.runner_group}" \
      --work _work

    # Start runner
    sudo -u "$${RUNNER_USER}" ./run.sh

    EOF

  tags = merge(
    local.tags,
    {
      Name = var.runner_name
    }
  )
}
