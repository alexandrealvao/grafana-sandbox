include "root" {
  path = find_in_parent_folders()
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders())}/_envcommon/network.hcl"
  # We want to reference the variables from the included config in this configuration, so we expose it.
  expose = true
}

terraform {
  source = "${include.envcommon.locals.base_source_url}?ref=2.3.1"
}

inputs = {
  vpc_cidr            = "172.16.0.0/16"
}