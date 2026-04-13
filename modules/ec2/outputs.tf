output "instance_ids" {
  description = "List of EC2 instance IDs"
  value       = aws_instance.this[*].id
}

output "private_ips" {
  description = "List of private IP addresses of the EC2 instances"
  value       = aws_instance.this[*].private_ip
}

output "availability_zones" {
  description = "List of availability zones where instances are deployed"
  value       = aws_instance.this[*].availability_zone
}

output "computed_names" {
  description = "List of computed instance names (name_prefix + zero-padded numbers)"
  value       = local.instance_names
}

# Additional EBS volume outputs
output "ebs_volume_ids" {
  description = "List of additional EBS volume IDs"
  value       = aws_ebs_volume.additional[*].id
}

output "volume_attachment_ids" {
  description = "List of EBS volume attachment IDs"
  value       = aws_volume_attachment.additional[*].id
}

# Drift detection outputs
output "drift_detection_data" {
  description = "Drift detection data for monitoring (only available when enable_drift_detection = true)"
  value = var.enable_drift_detection ? {
    instance_states  = data.aws_instance.drift_check[*].instance_state
    instance_types   = data.aws_instance.drift_check[*].instance_type
    attached_volumes = data.aws_ebs_volumes.attached_volumes[*].ids
    security_groups  = data.aws_instance.drift_check[*].vpc_security_group_ids
  } : null
  sensitive = false
}
