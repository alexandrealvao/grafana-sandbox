# Required
variable "customer" {
  description = "Customer short name, used in resource names and the Customer tag."
  type        = string
}

variable "environment" {
  description = "Environment name (e.g. labs), used in resource names and the Environment tag."
  type        = string
}

variable "owner" {
  description = "Owner of the resources, used in the Owner tag."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC the instances are deployed into."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC. Clients inside it may reach Grafana and the Alloy gateway."
  type        = string
}

variable "subnet_ids" {
  description = "Public subnet IDs. Instances are spread across them round-robin."
  type        = list(string)
}

variable "subnet_cidrs" {
  description = "CIDR blocks of subnet_ids, in the same order. Used to assign fixed private IPs."
  type        = list(string)
}

# Optional
variable "service" {
  description = "Service name used in the resource naming pattern."
  type        = string
  default     = "observability"
}

variable "name_prefix" {
  description = "Prefix for all resource names. Defaults to {customer}-{environment}-{service}."
  type        = string
  default     = null
}

variable "instance_type" {
  description = "EC2 instance type for all four instances (small x86_64 burstable is enough for a sandbox)."
  type        = string
  default     = "t3.small"
}

variable "root_volume_size" {
  description = "Size in GiB of the single (root) disk of each instance, which holds the OS and application data."
  type        = number
  default     = 30
}

variable "secret_recovery_window_in_days" {
  description = "Recovery window for the SSH key secrets on deletion (0 deletes immediately)."
  type        = number
  default     = 7
}

variable "admin_cidrs" {
  description = "Your IP(s) as CIDRs (e.g. 203.0.113.7/32). Allowed to reach SSH (22) on every instance, the Grafana UI (3000) and the Alloy UI (12345). Empty or null opens nothing."
  type        = list(string)
  default     = null

  validation {
    condition     = var.admin_cidrs != null && length(var.admin_cidrs) > 0
    error_message = "admin_cidrs must contain at least one CIDR (your IP as a /32); otherwise SSH and the UIs would be closed."
  }
}

variable "ping_allowed_cidrs" {
  description = "CIDR blocks allowed to ping (ICMP echo) every instance. Empty or null opens nothing."
  type        = list(string)
  default     = null
}

variable "public_nacl_id" {
  description = "ID of the public subnets' network ACL. Required for ping_allowed_cidrs to work: the NACL only allows echo replies in and echo requests out by default."
  type        = string
  default     = null
}

variable "dns_zone_name" {
  description = "Existing public Route 53 zone (e.g. labs3.dnx.host). When set, an A record <name_prefix>-<role>.<zone> is created per instance."
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags merged onto every resource."
  type        = map(string)
  default     = null
}
