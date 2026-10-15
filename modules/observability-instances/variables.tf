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

variable "tags" {
  description = "Additional tags merged onto every resource."
  type        = map(string)
  default     = null
}
