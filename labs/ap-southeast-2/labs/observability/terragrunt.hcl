include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${dirname(find_in_parent_folders())}/modules/observability-instances"
}

dependency "network" {
  config_path = "../network"

  mock_outputs = {
    vpc_id               = "vpc-00000000"
    cidr_block           = "172.16.0.0/16"
    public_nacl_id       = "acl-00000000"
    public_subnet_ids   = ["subnet-00000001", "subnet-00000002", "subnet-00000003"]
    public_subnet_cidrs = ["172.16.0.0/20", "172.16.16.0/20", "172.16.32.0/20"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate"]
}

inputs = {
  customer    = "dnx"
  owner       = "alexandre.alvao@dnx.solutions"
  environment = "labs"

  vpc_id       = dependency.network.outputs.vpc_id
  vpc_cidr     = dependency.network.outputs.cidr_block
  subnet_ids   = dependency.network.outputs.public_subnet_ids
  subnet_cidrs = dependency.network.outputs.public_subnet_cidrs

  name_prefix   = "grafana-sandbox"
  instance_type = "t3.small"

  # Ping from anywhere (requested). The NACL rules for it come from public_nacl_id.
  ping_allowed_cidrs = ["0.0.0.0/0"]
  public_nacl_id     = dependency.network.outputs.public_nacl_id

  # admin_cidrs (your public IP as a /32: SSH on all instances, Grafana 3000, Alloy UI 12345) is set
  # in the git-ignored terraform.tfvars next to this file. See terraform.tfvars.example.

  dns_zone_name = "labs3.dnx.host"
  # Inside the VPC the same names resolve to private IPs (needed for SG-referenced rules).
  private_dns = true
}
