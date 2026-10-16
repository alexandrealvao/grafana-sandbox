output "instance_ids" {
  description = "Instance IDs keyed by role (grafana, prometheus, database, alloy)."
  value       = { for role, i in aws_instance.this : role => i.id }
}

output "private_ips" {
  description = "Fixed private IPs keyed by role."
  value       = { for role, i in aws_instance.this : role => i.private_ip }
}

output "public_ips" {
  description = "Elastic IPs keyed by role."
  value       = { for role, e in aws_eip.this : role => e.public_ip }
}

output "security_group_ids" {
  description = "Security group IDs keyed by role."
  value       = { for role, sg in aws_security_group.this : role => sg.id }
}

output "ssh_private_key_secret_arn" {
  description = "Secrets Manager ARN holding the SSH private key shared by all instances."
  value       = aws_secretsmanager_secret.private_key.arn
}

output "grafana_port_forward_command" {
  description = "Command to reach the Grafana UI on http://localhost:3000 through SSM Session Manager."
  value       = "aws ssm start-session --target ${aws_instance.this["grafana"].id} --document-name AWS-StartPortForwardingSession --parameters portNumber=3000,localPortNumber=3000"
}

output "dns_names" {
  description = "Fully qualified DNS names keyed by role (empty when dns_zone_name is null)."
  value       = { for role, r in aws_route53_record.this : role => r.fqdn }
}
