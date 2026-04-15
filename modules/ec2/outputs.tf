output "instance_ids" {
  description = "List of EC2 instance IDs"
  value       = { for k, v in aws_instance.this : k => v.id }
}

output "private_ips" {
  description = "List of private IP addresses of the EC2 instances"
  value       = { for k, v in aws_instance.this : k => v.private_ip }
}

output "availability_zones" {
  description = "List of availability zones where instances are deployed"
  value       = { for k, v in aws_instance.this : k => v.availability_zone }
}

output "computed_names" {
  description = "List of computed instance names (name_prefix + zero-padded numbers)"
  value       = local.instance_names
}

# Additional EBS volume outputs
output "ebs_volume_ids" {
  description = "List of additional EBS volume IDs"
  value       = { for k, v in aws_ebs_volume.additional : k => v.id }
}

output "volume_attachment_ids" {
  description = "List of EBS volume attachment IDs"
  value       = { for k, v in aws_volume_attachment.additional : k => v.id }
}

# Drift detection outputs
output "drift_detection_data" {
  description = "Drift detection data for monitoring (only available when enable_drift_detection = true)"
  value = var.enable_drift_detection ? {
    instance_states  = { for k, v in data.aws_instance.drift_check : k => v.instance_state }
    instance_types   = { for k, v in data.aws_instance.drift_check : k => v.instance_type }
    attached_volumes = { for k, v in data.aws_ebs_volumes.attached_volumes : k => v.ids }
    security_groups  = { for k, v in data.aws_instance.drift_check : k => v.vpc_security_group_ids }
  } : null
  sensitive = false
}

# Combined instance details
output "instance_details" {
  description = "Complete details for all created instances"
  value = {
    for k, v in aws_instance.this : k => {
      id                = v.id
      arn               = v.arn
      private_ip        = v.private_ip
      availability_zone = v.availability_zone
      instance_type     = v.instance_type
      subnet_id         = v.subnet_id
      instance_state    = v.instance_state
    }
  }
}
