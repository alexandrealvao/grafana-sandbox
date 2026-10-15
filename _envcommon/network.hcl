locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env              = local.environment_vars.locals.environment
  base_source_url  = "git::https://github.com/DNXLabs/terraform-aws-network.git"
}

inputs = {
  name_pattern   = "default"
  max_az         = "3"
  newbits        = "4"
  name           = "grafana-sandbox"
  nat            = "true"
  multi_nat      = "false"
  transit_subnet = "false"
  vpc_flow_logs  = "false"

  kubernetes_clusters        = []
  kubernetes_clusters_secure = []
  kubernetes_clusters_type   = "shared"

  public_nacl_inbound_tcp_ports  = ["80", "443"]
  public_nacl_outbound_tcp_ports = ["0"]
  public_nacl_inbound_udp_ports  = []
  public_nacl_outbound_udp_ports = ["0"]
  public_nacl_icmp               = true

  vpc_endpoints                 = []
  vpc_endpoint_dynamodb_gateway = "false"
  vpc_endpoint_s3_gateway       = "false"

  create_dbsubgroup_private = "true"
  create_dbsubgroup_public  = "true"
}