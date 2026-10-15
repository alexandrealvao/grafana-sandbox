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
    private_subnet_ids   = ["subnet-00000001", "subnet-00000002", "subnet-00000003"]
    private_subnet_cidrs = ["172.16.0.0/20", "172.16.16.0/20", "172.16.32.0/20"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate"]
}

inputs = {
  customer    = "dnx"
  owner       = "alexandre.alvao@dnx.solutions"
  environment = "labs"

  vpc_id       = dependency.network.outputs.vpc_id
  vpc_cidr     = dependency.network.outputs.cidr_block
  subnet_ids   = dependency.network.outputs.private_subnet_ids
  subnet_cidrs = dependency.network.outputs.private_subnet_cidrs

  instance_type = "t3.small"
}
