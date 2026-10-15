output "instance_ids" {
  description = "Instance IDs keyed by role (grafana, prometheus, database, alloy)."
  value       = { for role, i in aws_instance.this : role => i.id }
}

output "private_ips" {
  description = "Fixed private IPs keyed by role."
  value       = { for role, i in aws_instance.this : role => i.private_ip }
}

output "security_group_ids" {
  description = "Security group IDs keyed by role."
  value       = { for role, sg in aws_security_group.this : role => sg.id }
}

output "data_volume_ids" {
  description = "Data EBS volume IDs keyed by role."
  value       = { for role, v in aws_ebs_volume.data : role => v.id }
}

output "ssh_private_key_secret_arns" {
  description = "Secrets Manager ARNs holding each instance's SSH private key, keyed by role."
  value       = { for role, s in aws_secretsmanager_secret.private_key : role => s.arn }
}

output "grafana_port_forward_command" {
  description = "Command to reach the Grafana UI on http://localhost:3000 through SSM Session Manager."
  value       = "aws ssm start-session --target ${aws_instance.this["grafana"].id} --document-name AWS-StartPortForwardingSession --parameters portNumber=3000,localPortNumber=3000"
}
