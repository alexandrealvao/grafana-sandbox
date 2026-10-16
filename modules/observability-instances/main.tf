# Amazon Linux 2023, x86_64 (t3 family). Resolved via the public SSM parameter so the latest AMI is used.
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  name_prefix = coalesce(var.name_prefix, "${var.customer}-${var.environment}-${var.service}")

  common_tags = merge(
    {
      Customer    = var.customer
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = var.owner
    },
    var.tags,
  )

  # IAM tag keys are case-insensitive, so "Owner" clashes with the provider default tag "owner".
  # IAM resources therefore omit Owner; the provider default tag still records the owner.
  iam_tags = { for k, v in local.common_tags : k => v if lower(k) != "owner" }

  # Sizing reasoning: t3.small (2 vCPU / 2 GiB) is enough for a sandbox. Each instance has a single
  # (root) disk that holds the OS and the application data.
  # Fixed private IPs (host offset inside the subnet) keep addresses stable across replacements.
  instances = {
    grafana = {
      subnet_index = 0
      host_offset  = 10
    }
    prometheus = {
      subnet_index = 1
      host_offset  = 10
    }
    database = {
      subnet_index = 2
      host_offset  = 10
    }
    alloy = {
      subnet_index = 0
      host_offset  = 11
    }
  }

  placement = {
    for role, cfg in local.instances : role => {
      subnet_id = var.subnet_ids[cfg.subnet_index % length(var.subnet_ids)]
      private_ip = cidrhost(
        var.subnet_cidrs[cfg.subnet_index % length(var.subnet_cidrs)],
        cfg.host_offset,
      )
    }
  }
}

############################################################################################################################################################
# SSH key pair (one shared key for all instances, private key kept in Secrets Manager)
################################################################################

resource "tls_private_key" "this" {
  algorithm = "ED25519"
}

resource "aws_key_pair" "this" {
  key_name   = local.name_prefix
  public_key = tls_private_key.this.public_key_openssh

  tags = local.common_tags
}

resource "aws_secretsmanager_secret" "private_key" {
  name                    = "${local.name_prefix}/ssh-private-key"
  description             = "Shared SSH private key (OpenSSH format) for the ${local.name_prefix} instances"
  recovery_window_in_days = var.secret_recovery_window_in_days

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "private_key" {
  secret_id     = aws_secretsmanager_secret.private_key.id
  secret_string = tls_private_key.this.private_key_openssh
}

####
# IAM (SSM Session Manager access)
################################################################################

data "aws_iam_policy_document" "assume_ec2" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${local.name_prefix}-ec2"
  assume_role_policy = data.aws_iam_policy_document.assume_ec2.json

  tags = local.iam_tags
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "this" {
  name = "${local.name_prefix}-ec2"
  role = aws_iam_role.this.name

  tags = local.iam_tags
}

################################################################################
# Security groups
################################################################################

resource "aws_security_group" "this" {
  for_each = local.instances

  name        = "${local.name_prefix}-${each.key}"
  description = "${each.key} instance"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-${each.key}" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_egress_rule" "all" {
  for_each = local.instances

  security_group_id = aws_security_group.this[each.key].id
  description       = "Allow all outbound (NAT for package installs, SSM)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = local.common_tags
}

locals {
  # node_exporter (9100) on every instance, scraped by the Alloy gateway.
  node_exporter_rules = {
    for role in keys(local.instances) : "${role}-node-exporter" => {
      target      = role
      port        = 9100
      source_type = "sg"
      source      = "alloy"
      description = "Alloy scrapes node_exporter"
    }
  }

  # "Your IP" access: SSH on every instance, Grafana UI, and the Alloy UI.
  admin_access = concat(
    [for role in keys(local.instances) : { role = role, port = 22 }],
    [{ role = "grafana", port = 3000 }, { role = "alloy", port = 12345 }],
  )

  # source is either a CIDR ("cidr") or another role's security group ("sg").
  ingress_rules = {
    prometheus-from-grafana = {
      target      = "prometheus", port = 9090, source_type = "sg", source = "grafana"
      description = "Grafana queries Prometheus"
    }
    prometheus-from-alloy = {
      target      = "prometheus", port = 9090, source_type = "sg", source = "alloy"
      description = "Alloy gateway remote_write to Prometheus"
    }
    database-from-grafana = {
      target      = "database", port = 5432, source_type = "sg", source = "grafana"
      description = "Grafana connects to PostgreSQL"
    }
    database-from-alloy = {
      target      = "database", port = 5432, source_type = "sg", source = "alloy"
      description = "Alloy connects to PostgreSQL"
    }
    alloy-otlp-grpc = {
      target      = "alloy", port = 4317, source_type = "cidr", source = var.vpc_cidr
      description = "OTLP gRPC from the VPC"
    }
    alloy-otlp-http = {
      target      = "alloy", port = 4318, source_type = "cidr", source = var.vpc_cidr
      description = "OTLP HTTP from the VPC"
    }
  }
}

resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = merge(local.ingress_rules, local.node_exporter_rules)

  security_group_id            = aws_security_group.this[each.value.target].id
  description                  = each.value.description
  ip_protocol                  = "tcp"
  from_port                    = each.value.port
  to_port                      = each.value.port
  cidr_ipv4                    = each.value.source_type == "cidr" ? each.value.source : null
  referenced_security_group_id = each.value.source_type == "sg" ? aws_security_group.this[each.value.source].id : null

  tags = local.common_tags
}

################################################################################
# Instances
################################################################################

resource "aws_instance" "this" {
  for_each = local.instances

  ami           = data.aws_ssm_parameter.al2023.value
  instance_type = var.instance_type
  key_name      = aws_key_pair.this.key_name
  subnet_id     = local.placement[each.key].subnet_id
  private_ip    = local.placement[each.key].private_ip
  # associate_public_ip_address is left to the subnet default: the subnet auto-assigns a public IP at
  # launch and AWS reports true, so forcing false would replace the instance on every plan.
  # The Elastic IP below becomes the instance's public address once attached.
  vpc_security_group_ids = [aws_security_group.this[each.key].id]
  iam_instance_profile   = aws_iam_instance_profile.this.name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size
    encrypted   = true

    tags = merge(local.common_tags, { Name = "${local.name_prefix}-${each.key}-root" })
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-${each.key}", Role = each.key })

  lifecycle {
    # Avoid replacing instances when a newer AL2023 AMI is published.
    ignore_changes = [ami]
  }

  depends_on = [aws_vpc_security_group_egress_rule.all]
}

# Admin access from admin_cidrs: SSH (22) on all instances, Grafana UI (3000), Alloy UI (12345).
# The public NACL (network stack) allows inbound 22 and the 1024-65535 range, which covers the rest.
resource "aws_vpc_security_group_ingress_rule" "admin" {
  for_each = {
    for pair in setproduct(local.admin_access, coalesce(var.admin_cidrs, [])) :
    "${pair[0].role}-${pair[0].port}-${pair[1]}" => { role = pair[0].role, port = pair[0].port, cidr = pair[1] }
  }

  security_group_id = aws_security_group.this[each.value.role].id
  description       = "Port ${each.value.port} from ${each.value.cidr}"
  ip_protocol       = "tcp"
  from_port         = each.value.port
  to_port           = each.value.port
  cidr_ipv4         = each.value.cidr

  tags = local.common_tags
}

# Ping (ICMP echo request, type 8) from ping_allowed_cidrs on every instance.
resource "aws_vpc_security_group_ingress_rule" "ping" {
  for_each = {
    for pair in setproduct(keys(local.instances), coalesce(var.ping_allowed_cidrs, [])) :
    "${pair[0]}-${pair[1]}" => { role = pair[0], cidr = pair[1] }
  }

  security_group_id = aws_security_group.this[each.value.role].id
  description       = "Ping from ${each.value.cidr}"
  ip_protocol       = "icmp"
  from_port         = 8
  to_port           = -1
  cidr_ipv4         = each.value.cidr

  tags = local.common_tags
}

# The public NACL (owned by the network stack) only lets echo replies in and echo requests out, so
# add echo request in (type 8) and echo reply out (type 0). Rule numbers 520+ avoid the module's 501.
locals {
  ping_nacl_cidrs = var.public_nacl_id == null ? {} : { for i, c in coalesce(var.ping_allowed_cidrs, []) : tostring(520 + i) => c }
}

resource "aws_network_acl_rule" "ping_in" {
  for_each = local.ping_nacl_cidrs

  network_acl_id = var.public_nacl_id
  rule_number    = tonumber(each.key)
  egress         = false
  protocol       = "icmp"
  rule_action    = "allow"
  cidr_block     = each.value
  icmp_type      = 8
  icmp_code      = -1
}

resource "aws_network_acl_rule" "ping_out" {
  for_each = local.ping_nacl_cidrs

  network_acl_id = var.public_nacl_id
  rule_number    = tonumber(each.key)
  egress         = true
  protocol       = "icmp"
  rule_action    = "allow"
  cidr_block     = each.value
  icmp_type      = 0
  icmp_code      = -1
}

################################################################################
# Elastic IPs (stable public addresses; security groups still only allow VPC traffic)
################################################################################

resource "aws_eip" "this" {
  for_each = local.instances

  domain   = "vpc"
  instance = aws_instance.this[each.key].id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-${each.key}" })
}

################################################################################
# DNS (A records in an existing public hosted zone)
################################################################################

data "aws_route53_zone" "public" {
  count = var.dns_zone_name == null ? 0 : 1

  name         = var.dns_zone_name
  private_zone = false
}

resource "aws_route53_record" "this" {
  for_each = var.dns_zone_name == null ? {} : local.instances

  zone_id = data.aws_route53_zone.public[0].zone_id
  name    = "${local.name_prefix}-${each.key}.${var.dns_zone_name}"
  type    = "A"
  ttl     = 300
  records = [aws_eip.this[each.key].public_ip]
}
