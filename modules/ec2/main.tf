terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

locals {
  # Enhanced instance numbering logic with backward compatibility
  # Priority: explicit_instance_numbers > starting_instance_number + instance_count > default (1-N)

  instance_numbers = length(var.explicit_instance_numbers) > 0 ? var.explicit_instance_numbers : [
    for i in range(var.instance_count) : var.starting_instance_number + i
  ]

  # Generate computed instance names with zero-padded numbers (01-99)
  instance_names = [
    for num in local.instance_numbers : "${var.name_prefix}${format("%02d", num)}"
  ]

  instances = {
    for idx, name in local.instance_names : name => {
      instance_number = local.instance_numbers[idx]
      subnet_id       = var.subnet_ids[idx % length(var.subnet_ids)]
      instance_type   = lookup(var.instance_types_by_name, name, var.default_instance_type)
    }
  }

  additional_ebs_volumes = {
    for item in flatten([
      for instance_name, instance in local.instances : [
        for volume in var.ebs_block_devices : {
          key           = "${instance_name}-${volume.name_suffix}-${replace(volume.device_name, "/", "_")}"
          instance_name = instance_name
          device_name   = volume.device_name
          name_suffix   = volume.name_suffix
          volume_type   = volume.volume_type
          volume_size   = volume.volume_size
          iops   = try(volume.volume_iops, null)
          throughput    = try(volume.throughput, null)
          kms_key_id    = try(volume.kms_key_id, null)
        }
      ]
    ]) : item.key => item
  }

  # Determine actual instance count based on configuration
  actual_instance_count = length(var.explicit_instance_numbers) > 0 ? length(var.explicit_instance_numbers) : var.instance_count
}

check "instance_type_override_keys_valid" {
  assert {
    
    condition     = alltrue([for k in keys(var.instance_types_by_name) : contains(local.instance_names, k)])
    error_message = "All values in instance_types_by_name must match generated instance names."
  }
}

check "subnet_ids_not_empty" {
  assert {
    condition     = length(var.subnet_ids) > 0
    error_message = "var.subnet_ids must contain at least one subnet ID."
  }
}

check "instance_number_inputs_valid" {
  assert {
    condition = (
      (length(var.explicit_instance_numbers) > 0 || var.instance_count > 0) &&
      length(distinct(var.explicit_instance_numbers)) == length(var.explicit_instance_numbers) &&
      alltrue([for n in var.explicit_instance_numbers : n > 0]) &&
      var.starting_instance_number > 0
    )
    error_message = "Provide either explicit_instance_numbers or a positive instance_count. explicit_instance_numbers must be unique positive integers, and starting_instance_number must be > 0."
  }
}

check "root_volume_settings_valid" {
  assert {
    condition = (
      contains(["gp2", "gp3", "io1", "io2", "st1", "sc1", "standard"], var.root_volume.volume_type) &&
      var.root_volume.volume_size > 0 &&
      (
        contains(["gp3", "io1", "io2"], var.root_volume.volume_type) ||
        try(var.root_volume.volume_iops, null) == null
      ) &&
      (
        var.root_volume.volume_type == "gp3" ||
        try(var.root_volume.throughput, null) == null
      )
    )
    error_message = "root_volume has invalid settings. IOPS are only valid for gp3/io1/io2. Throughput is only valid for gp3."
  }
}

check "additional_ebs_settings_valid" {
  assert {
    condition = alltrue([
      for v in var.ebs_block_devices : (
        contains(["gp2", "gp3", "io1", "io2", "st1", "sc1", "standard"], v.volume_type) &&
        v.volume_size > 0 &&
        length(trimspace(v.device_name))> 0 &&
        length(trimspace(v.name_suffix))> 0 &&
        (
          contains(["gp3", "io1", "io2"], v.volume_type) ||
          try(v.volume_iops, null) == null
        ) &&
        (
          v.volume_type == "gp3" ||
          try(v.throughput, null) == null
        )
      )
    ])
    error_message = "Each ebs_block_devices entry must have valid type, size, device_name, and name_suffix. IOPS are only valid for gp3/io1/io2. Throughput is only valid for gp3."
  }
}


resource "aws_instance" "this" {
  for_each = local.instances

  ami           = each.value.ami_id
  instance_type = each.value.instance_type

  # Spread instances across subnets using modulo
  subnet_id = each.value.subnet_id

  vpc_security_group_ids = var.vpc_security_group_ids
  key_name               = var.key_name

  # CID 433: IAM instance profile required
  iam_instance_profile = var.iam_instance_profile

  # CID monitoring enabled
  monitoring = var.enable_monitoring

  # CID 357: EBS optimized = true
  ebs_optimized = true

  disable_api_termination = var.enable_termination_protection

  # Force IMDSv2 and metadata configuration
  metadata_options {
    http_tokens                 = var.metadata_options_http_tokens
    instance_metadata_tags      = var.metadata_options_instance_metadata_tags
    http_put_response_hop_limit = var.metadata_options_http_put_response_hop_limit
  }

  # Root volume with forced encryption
  root_block_device {
    volume_type = var.root_volume.volume_type
    volume_size = var.root_volume.volume_size
    iops = try(var.root_volume.volume_iops, null)
    throughput  = try(var.root_volume.throughput, null)
    delete_on_termination = try(var.root_volume.delete_on_termination, true)
    encrypted   = true # Force encryption
    kms_key_id  = try(var.root_volume.kms_key_id, null)

    tags = merge(
      var.tags,
      var.volume_tags,
      {
        Name = "${each.key}-root-volume"
      }
    )
  }

  # Additional EBS volumes with forced encryption (inline - for initial deployment only)
  #dynamic "ebs_block_device" {
  #  for_each = var.inline_ebs_block_devices
  #  content {
  #    device_name = ebs_block_device.value.device_name
  #    volume_type = ebs_block_device.value.volume_type
  #    volume_size = ebs_block_device.value.volume_size
  #    iops = ebs_block_device.value.volume_iops
  #    encrypted   = true # Force encryption
  #    kms_key_id  = ebs_block_device.value.kms_key_id

  #    tags = merge(
  #      var.tags,
  #      var.volume_tags,
  #      {
  #        Name = "${each.key}-${ebs_block_device.value.name_suffix}"
  #      }
  #    )
  #  }
  #}

  # Drift detection and lifecycle management
  lifecycle {
    precondition {
      condition = alltrue([
        for name in local.instance_names : length(name) <= 15
      ])
      error_message = "Generated server names must be 15 characters or fewer. Offending names: ${join(", ", [for name in local.instance_names : name if length(name) > 15])}"
    }

    ignore_changes = [
      # Ignore changes to AMI if using latest
      ami,
      # Ignore user_data changes if managed externally
      user_data,
      # Ignore metadata options changes if managed by compliance tools
      metadata_options
    ]

    # Prevent accidental deletion
    prevent_destroy = false # Set to true in production
  }

  # Instance tags - Name tag uses computed name without hyphens
  tags = merge(
    var.tags,
    {
      Name = each.key
    }
  )
}

resource "aws_ebs_volume" "additional" {
  for_each = local.additional_ebs_volumes

  availability_zone = aws_instance.this[each.value.instance_name].availability_zone
  type              = each.value.volume_type
  size              = each.value.volume_size
  iops              = each.value.volume_iops
  throughput        = each.value.throughput
  encrypted         = true
  kms_key_id        = each.value.kms_key_id

  tags = merge(
    var.tags,
    var.volume_tags,
    {
      Name       = "${each.value.instance_name}-${each.value.name_suffix}"
      InstanceId = aws_instance.this[each.value.instance_name].id
      DeviceName = each.value.device_name
    }
  )

  lifecycle {
    # Prevent accidental deletion
    prevent_destroy = false # Set to true in production

    # Ignore size changes if managed by auto-scaling
    ignore_changes = []
  }
}

# Volume attachments for EBS volumes
resource "aws_volume_attachment" "additional" {
  for_each = local.additional_ebs_volumes

  device_name = each.value.device_name
  volume_id   = aws_ebs_volume.additional[each.key].id
  instance_id = aws_instance.this[each.value.instance_name].id

  # Force detachment on destroy to prevent hanging volumes
  force_detach = var.force_detach_volumes

  lifecycle {
    # Ensure volumes exist before attachment
    create_before_destroy = true
  }
}

# Drift detection - Data sources for validation
data "aws_instance" "drift_check" {
  for_each = var.enable_drift_detection ? aws_instance.this : {}

  instance_id = each.value.id

  depends_on = [aws_instance.this]
}

data "aws_ebs_volumes" "attached_volumes" {
  for_each = var.enable_drift_detection ? aws_instance.this : {}

  filter {
    name   = "attachment.instance-id"
    values = [each.value.id]
  }

  depends_on = [aws_volume_attachment.additional]
}
