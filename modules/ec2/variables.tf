variable "name_prefix" {
  description = "Name prefix for EC2 instances (will be suffixed with 01-99)"
  type        = string
}

variable "instance_count" {
  description = "Number of EC2 instances to create (1-99)"
  type        = number
  default     = 1

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 99
    error_message = "Instance count must be between 1 and 99."
  }
}

variable "starting_instance_number" {
  description = "Starting instance number for sequential numbering (default: 1 for backward compatibility)"
  type        = number
  default     = 1

  validation {
    condition     = var.starting_instance_number >= 1 && var.starting_instance_number <= 99
    error_message = "Starting instance number must be between 1 and 99."
  }
}

variable "explicit_instance_numbers" {
  description = "Explicit instance numbers (overrides starting_instance_number and instance_count if provided)"
  type        = list(number)
  default     = []

  validation {
    condition = length(var.explicit_instance_numbers) == 0 || (
      alltrue([for n in var.explicit_instance_numbers : n >= 1 && n <= 99]) &&
      length(var.explicit_instance_numbers) <= 99
    )
    error_message = "All explicit instance numbers must be between 1 and 99, and list cannot exceed 99 entries."
  }
}

variable "default_instance_type" {
  type        = string
  description = "Default EC2 instance type used when no per-instance override is provided"
}

variable "instance_types_by_name" {
  type        = map(string)
  description = "Optional per-instance type overrides keyed by generated instance name"
  default     = {}

  validation {
    condition = alltrue([for v in values(var.instance_types_by_name) : length(trimspace(v))> 0])
    error_message = "All values in instance_types_by_name must be non-empty instance type strings."
  }
}

variable "ami_id" {
  description = "AMI ID for EC2 instances"
  type        = string
}


variable "subnet_ids" {
  description = "List of subnet IDs for instance placement (instances will be spread across using modulo)"
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "subnet_ids must contain at least one subnet."
  }
}

variable "vpc_security_group_ids" {
  description = "List of security group IDs to associate with instances"
  type        = list(string)
}

variable "key_name" {
  description = "Key pair name for EC2 instances"
  type        = string
  default     = null
}

variable "iam_instance_profile" {
  description = "IAM instance profile name (required per CID 433)"
  type        = string
}

variable "enable_monitoring" {
  description = "Enable detailed CloudWatch monitoring (CID monitoring)"
  type        = bool
  default     = true
}

variable "metadata_options_http_tokens" {
  description = "Whether or not the metadata service requires session tokens (IMDSv2)"
  type        = string
  default     = "required"
}

variable "metadata_options_instance_metadata_tags" {
  description = "Enables or disables access to instance tags from the instance metadata service"
  type        = string
  default     = "enabled"

  validation {
    condition     = contains(["enabled", "disabled"], var.metadata_options_instance_metadata_tags)
    error_message = "metadata_options_instance_metadata_tags must be enabled or disabled."
  }
}

variable "metadata_options_http_put_response_hop_limit" {
  description = "The desired HTTP PUT response hop limit for instance metadata requests"
  type        = number
  default     = 1

  validation {
    condition     = var.metadata_options_http_put_response_hop_limit >= 1 && var.metadata_options_http_put_response_hop_limit <= 64
    error_message = "metadata_options_http_put_response_hop_limit must be between 1 and 64."
  }
}

variable "root_volume" {
  description = "Root volume configuration"
  type = object({
    volume_type = string
    volume_size = number
    volume_iops = optional(number)
    throughput  = optional(number)
    kms_key_id  = optional(string)
  })
  default = {
    volume_type = "gp3"
    volume_size = 20
    volume_iops = 3000
  }
}

variable "ebs_block_devices" {
  description = "Additional EBS block devices to attach to instances (attached separately for non-disruptive changes)"
  type = list(object({
    name_suffix = string
    device_name = string
    volume_type = string
    volume_size = number
    volume_iops = optional(number)
    throughput = optional(number)
    kms_key_id  = optional(string)
  }))
  default = []
}

variable "enable_drift_detection" {
  description = "Enable drift detection data sources for monitoring configuration changes"
  type        = bool
  default     = true
}

variable "tags" {
  description = "A map of tags to assign to all resources"
  type        = map(string)
  default     = {}
}

variable "volume_tags" {
  description = "Additional tags to apply to EBS volumes (merged with main tags)"
  type        = map(string)
  default     = {}
}

variable "enable_termination_protection" {
  description = "Enable termination protection for instances"
  type        = bool
  default     = true
}

variable "protect_from_destroy" {
  type        = bool
  description = "Prevent accidental instance deletion"
  default     = true
}

variable "protect_data_volumes" {
  type        = bool
  description = "Prevent accidental EBS volume deletion"
  default     = true
}

variable "force_detach_volumes" {
  type        = bool
  description = "Force detach EBS volumes during destroy operations"
  default     = false
}
