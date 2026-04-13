# EC2 Module (modules/ec2)

A comprehensive, enterprise-grade AWS EC2 instance module with multi-instance support, brownfield-friendly naming, CIS-aligned compliance controls, EBS volume management, and advanced monitoring capabilities.

## Features

- **Multi-Instance Support** - Deploy 1-99 instances with consistent zero-padded naming
- **Flexible Instance Numbering** - Support sequential numbering, custom starting numbers, and explicit instance numbers
- **Brownfield-Friendly Deployment - Avoid naming collisions when extending existing environments
- **Windows Hostname Guardrails - Validate generated hostnames for Windows deployments
- **CIS AWS Foundations Benchmark Compliance** - Built-in security controls and hardening
- **Enterprise Security** - IMDSv2 enforcement, encryption at rest, and termination protection
- **EBS Volume Management** - Root and additional volumes with encryption and monitoring
- **Subnet Distribution** - Intelligent spreading across availability zones for high availability
- **Drift Detection** - Monitor configuration changes and compliance violations
- **Comprehensive Monitoring** - CloudWatch integration with detailed instance metrics
- **Private Module Consumption - Supports central Terraform module access from GitHub Actions using a GitHub App

## Architecture

```
┌─────────────────────────────────────────────────┐
│                Multi-Instance Deployment         │
├─────────────────────────────────────────────────┤
│  Instance 01      Instance 02      Instance 03  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │
│  │   AMI ID    │  │   AMI ID    │  │   AMI ID    │ │
│  │ Instance    │  │ Instance    │  │ Instance    │ │
│  │   Type      │  │   Type      │  │   Type      │ │
│  └─────────────┘  └─────────────┘  └─────────────┘ │
│       │                  │                  │      │
├───────▼──────────────────▼──────────────────▼──────┤
│              Subnet Distribution                   │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │
│  │ Subnet-A    │  │ Subnet-B    │  │ Subnet-C    │ │
│  │ AZ-1a       │  │ AZ-1b       │  │ AZ-1c       │ │
│  └─────────────┘  └─────────────┘  └─────────────┘ │
└─────────────────────────────────────────────────────┘
                      ▼
┌─────────────────────────────────────────────────────┐
│              Security & Compliance                  │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────┐ │
│  │ Security    │ │ EBS         │ │ IAM Instance    │ │
│  │ Groups      │ │ Encryption  │ │ Profile         │ │
│  └─────────────┘ └─────────────┘ └─────────────────┘ │
└─────────────────────────────────────────────────────┘
                      ▼
┌─────────────────────────────────────────────────────┐
│              Monitoring & Management                │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────┐ │
│  │ CloudWatch  │ │ Drift       │ │ Metadata        │ │
│  │ Monitoring  │ │ Detection   │ │ Service v2      │ │
│  └─────────────┘ └─────────────┘ └─────────────────┘ │
└─────────────────────────────────────────────────────┘
```

## Quick Start

### Single Instance Deployment

```hcl
module "web_server" {
  source = "./modules/ec2"
  
  name_prefix    = "web-server"
  instance_count = 1
  
  ami_id        = "ami-0abcdef1234567890"
  instance_type = "t3.medium"
  
  subnet_ids             = ["subnet-12345678"]
  vpc_security_group_ids = ["sg-87654321"]
  iam_instance_profile   = "EC2-SSMRole"
  
  # CIS compliance enabled by default
  enable_monitoring           = true
  enable_termination_protection = true
  
  tags = {
    Environment = "production"
    Application = "web-server"
    Owner       = "platform-team"
  }
}
```

## Flexible Instance Numbering

This module now supports multiple naming patterns for both greenfield and brownfield use cases.

### Default Sequential Numbering
If no numbering inputs are provided, numbering starts at 01.

```hcl
module "existing_deployment" {
  source = "./modules/ec2"

  name_prefix    = "instance" #Creates instance01, instance02 and instance03
  instance_count = 3

  ami_id                 = "ami-0abcdef1234567890"
  instance_type          = "t3.medium"
  subnet_ids             = ["subnet-12345678"]
  vpc_security_group_ids = ["sg-87654321"]
  iam_instance_profile   = "EC2-SSMRole"
}
```


### Custom Starting Number

Use this when lower instance numbers already exist, to avoid conflicts and skip existing instance numbers:

```hcl
module "app_expansion" {
  source = "./modules/ec2"
  
  name_prefix              = "myapp"
  instance_count           = 3
  starting_instance_number = 5  # Creates: myapp05, myapp06, myapp07
  
  ami_id        = "ami-0abcdef1234567890"
  instance_type = "t3.medium"
  subnet_ids    = ["subnet-12345678"]
  vpc_security_group_ids = ["sg-87654321"]
  iam_instance_profile   = "EC2-SSMRole"
  
  # Scenario: myapp01-04 already exist from previous deployment
  # This creates new instances without conflicts
}
```

### Explicit Instance Numbers

Use this when you need exact numbering, such as selective replacement or filling gaps:

```hcl
module "database_cluster" {
  source = "./modules/ec2"
  
  name_prefix               = "db-cluster"
  explicit_instance_numbers = [3, 7, 12]  # Creates: db-cluster03, db-cluster07, db-cluster12
  
  ami_id        = "ami-database-hardened"
  instance_type = "r5.large"
  subnet_ids    = ["subnet-db-1", "subnet-db-2", "subnet-db-3"]
  vpc_security_group_ids = ["sg-database"]
  iam_instance_profile   = "DatabaseRole"
  
  # Scenario: Fill specific gaps in existing cluster numbering
  # Perfect for disaster recovery or selective replacement
}
```

### Gap Filling Example

Replace failed instances while maintaining naming consistency:

```hcl
module "failed_instance_replacement" {
  source = "./modules/ec2"
  
  name_prefix               = "web-server"
  explicit_instance_numbers = [2, 5]  # Replace only failed instances
  
  ami_id        = "ami-updated-2024"
  instance_type = "t3.medium"
  subnet_ids    = ["subnet-web-tier"]
  vpc_security_group_ids = ["sg-web-servers"]
  iam_instance_profile   = "WebServerRole"
  
  tags = {
    Purpose     = "replacement"
    Replaced    = "2024-03-19"
    Environment = "production"
  }
}
```

### Backward Compatibility

All existing deployments continue working without changes:

```hcl
# This still works exactly as before (creates instance01, instance02, instance03)
module "existing_deployment" {
  source = "./modules/ec2"
  
  name_prefix    = "instance"
  instance_count = 3
  # No starting_instance_number or explicit_instance_numbers = defaults to 1, 2, 3
  
  ami_id        = "ami-0abcdef1234567890"
  instance_type = "t3.medium"
  subnet_ids    = ["subnet-12345678"]
  vpc_security_group_ids = ["sg-87654321"]
  iam_instance_profile   = "EC2-SSMRole"
}
```

### Multi-Instance High Availability Deployment

```hcl
module "app_cluster" {
  source = "./modules/ec2"
  
  name_prefix    = "app-cluster"
  instance_count = 6  # Creates: app-cluster01, app-cluster02, ..., app-cluster06
  
  ami_id        = "ami-0abcdef1234567890"
  instance_type = "c5.large"
  
  # Multi-AZ subnet distribution (instances spread automatically)
  subnet_ids = [
    "subnet-12345678",  # us-east-1a
    "subnet-87654321",  # us-east-1b 
    "subnet-11223344"   # us-east-1c
  ]
  
  vpc_security_group_ids = [
    module.app_security_group.security_group_id,
    module.monitoring_security_group.security_group_id
  ]
  
  iam_instance_profile = "ApplicationServerRole"
  key_name            = "production-keypair"
  
  # Enhanced monitoring and security
  enable_monitoring           = true
  enable_termination_protection = true
  enable_drift_detection     = true
  
  # Custom root volume configuration
  root_volume = {
    volume_type = "gp3"
    volume_size = 100
    kms_key_id  = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
  }
  
  # Additional EBS volumes per instance
  create_additional_ebs_volume = true
  additional_ebs_volume = {
    volume_type = "gp3"
    volume_size = 500
    device_name = "/dev/sdf"
    kms_key_id  = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
  }
  
  tags = {
    Environment    = "production"
    Application    = "backend-services"
    Team          = "application-team"
    CostCenter    = "engineering"
    BackupPolicy  = "daily"
  }
  
  volume_tags = {
    BackupRequired = "true"
    DataClass     = "sensitive"
  }
}
```

### Enterprise Database Servers

```hcl
module "database_servers" {
  source = "./modules/ec2"
  
  name_prefix    = "db-primary"
  instance_count = 2  # Creates: db-primary01, db-primary02
  
  ami_id        = "ami-database-hardened"
  instance_type = "r5.xlarge"  # Memory optimized for databases
  
  subnet_ids = [
    "subnet-db-private-1a",
    "subnet-db-private-1b"
  ]
  
  vpc_security_group_ids = [
    module.database_security_group.security_group_id
  ]
  
  iam_instance_profile = "DatabaseServerRole"
  
  # Database-specific configuration
  enable_monitoring           = true
  enable_termination_protection = true
  enable_drift_detection     = true
  
  # Enhanced metadata security (CIS requirement)
  metadata_options_http_tokens = "required"  # IMDSv2 only
  metadata_options_http_put_response_hop_limit = 1
  
  # Large root volume for database
  root_volume = {
    volume_type = "gp3"
    volume_size = 200
    kms_key_id  = "arn:aws:kms:us-east-1:123456789012:key/database-key"
  }
  
  # Data volume for database files
  create_additional_ebs_volume = true
  additional_ebs_volume = {
    volume_type = "gp3"
    volume_size = 2000  # 2TB for database storage
    device_name = "/dev/sdf"
    kms_key_id  = "arn:aws:kms:us-east-1:123456789012:key/database-key"
  }
  
  tags = {
    Environment     = "production"
    Application     = "database"
    Tier           = "data"
    BackupPolicy   = "continuous"
    MaintenanceWindow = "sunday-2am"
  }
}
```

## Configuration

### Required Variables

| Variable | Type | Description |
|----------|------|-------------|
| `name_prefix` | `string` | Name prefix for instances (will be suffixed with 01-99) |
| `ami_id` | `string` | AMI ID for EC2 instances |
| `instance_type` | `string` | EC2 instance type |
| `subnet_ids` | `list(string)` | List of subnet IDs (instances spread using modulo) |
| `vpc_security_group_ids` | `list(string)` | List of security group IDs |
| `iam_instance_profile` | `string` | IAM instance profile name (CIS requirement) |

### Optional Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `instance_count` | `number` | `1` | Number of instances to create (1-99) |
| `starting_instance_number` | `number` | `1` | **v2.1.1+** Starting instance number for sequential numbering |
| `explicit_instance_numbers` | `list(number)` | `[]` | **v2.1.1+** Explicit instance numbers (overrides instance_count) |
| `key_name` | `string` | `null` | EC2 Key Pair name for SSH access |
| `enable_monitoring` | `bool` | `true` | Enable detailed CloudWatch monitoring |
| `enable_termination_protection` | `bool` | `false` | Enable termination protection |
| `enable_drift_detection` | `bool` | `false` | Enable configuration drift detection |
| `create_additional_ebs_volume` | `bool` | `false` | Create additional EBS volume per instance |

### Root Volume Configuration

```hcl
root_volume = {
  volume_type = "gp3"        # Volume type: gp3, gp2, io1, io2
  volume_size = 50           # Size in GB
  volume_iops = 3000         # Provisioned IOPS
  volume_throughput = 128    # Throughput required for the volume
  kms_key_id  = "alias/aws/ebs"  # KMS key for encryption
}
```

### Additional EBS Volume Configuration

```hcl
additional_ebs_volume = {
  volume_type = "gp3"
  volume_size = 100
  device_name = "/dev/sdf"
  volume_iops = 3000         # Provisioned IOPS
  volume_throughput = 128    # Throughput required for the volume
  kms_key_id  = "alias/aws/ebs"
}
```

### Metadata Options (Security Hardening)

```hcl
# IMDSv2 enforcement (CIS requirement)
metadata_options_http_tokens = "required"  # required|optional
metadata_options_instance_metadata_tags = "enabled"
metadata_options_http_put_response_hop_limit = 1
```

## Outputs

### Instance Information
- `instance_ids` - List of EC2 instance IDs
- `private_ips` - List of private IP addresses
- `availability_zones` - List of AZs where instances are deployed
- `computed_names` - List of computed instance names with zero-padding

### Volume Information
- `ebs_volume_ids` - List of additional EBS volume IDs
- `volume_attachment_ids` - List of volume attachment IDs

### Monitoring
- `drift_detection_data` - Configuration drift monitoring data (when enabled)

## Enterprise Features

### 🔒 CIS AWS Foundations Benchmark Compliance

- **CIS 2.2.1** - IMDSv2 enforcement for instance metadata
- **CIS 2.8** - EBS encryption enabled by default
- **CIS 4.33** - IAM instance profiles required for all instances
- **CIS 5.1** - CloudWatch monitoring enabled by default

### 🛡️ Security Controls

- **Encryption at Rest** - All EBS volumes encrypted with KMS
- **Termination Protection** - Prevent accidental instance termination
- **Security Group Integration** - Multiple security group support
- **Network Isolation** - VPC subnet placement with AZ distribution

### 📊 Monitoring & Compliance

- **Drift Detection** - Monitor configuration changes and unauthorized modifications
- **CloudWatch Integration** - Detailed monitoring and metrics collection
- **Tag Standardization** - Comprehensive tagging for governance and cost allocation

### 🏗️ High Availability Patterns

- **Multi-AZ Distribution** - Automatic spreading across provided subnets
- **Scalable Deployment** - Support for 1-99 instances with consistent naming
- **Zero-Padded Naming** - Enterprise-friendly naming convention (prefix01-99)

## Migration from Legacy Modules

### From Single Instance Module

```hcl
# Legacy (modules/ec2)
module "legacy_instance" {
  source = "./modules/ec2"
  name   = "web-server"
  # ... other variables
}

# New (modules/ec2) - Backward Compatible
module "new_instance" {
  source = "./modules/ec2"
  name_prefix    = "web-server"  # Will create: web-server01
  instance_count = 1             # Single instance (default)
  # ... other variables (mostly same)
}
```

### Scaling Existing Deployments

```hcl
# Scale from 1 to 3 instances
module "scaled_deployment" {
  source = "./modules/ec2"
  name_prefix    = "web-server"
  instance_count = 3  # Now creates: web-server01, web-server02, web-server03
  # ... keep existing configuration
}
```

## Best Practices

### 🎯 Naming Conventions

- Use descriptive prefixes: `web-server`, `app-backend`, `db-primary`
- Environment prefixes: `prod-web`, `dev-app`, `staging-db`
- Team prefixes: `platform-web`, `data-analytics`

### 🔍 Monitoring Strategy

```hcl
# Enable comprehensive monitoring
enable_monitoring      = true
enable_drift_detection = true

# Use consistent tagging
tags = {
  Environment    = "production"
  Application    = "web-application"
  Team          = "platform"
  CostCenter    = "engineering"
  BackupPolicy  = "daily"
  Owner         = "platform-team@company.com"
}
```

### 🏭 Multi-Tier Application Example

```hcl
# Web Tier (load balanced)
module "web_tier" {
  source = "./modules/ec2"
  name_prefix    = "web"
  instance_count = 3
  instance_type  = "t3.medium"
  # ... web tier configuration
}

# Application Tier (auto-scaling)
module "app_tier" {
  source = "./modules/ec2"
  name_prefix    = "app"
  instance_count = 6
  instance_type  = "c5.large"
  # ... application tier configuration
}

# Database Tier (redundant)
module "db_tier" {
  source = "./modules/ec2"
  name_prefix    = "db"
  instance_count = 2
  instance_type  = "r5.xlarge"
  # ... database tier configuration
}
```

## Troubleshooting

### Common Issues

1. **Instance Count Validation Error**
   ```
   Error: Instance count must be between 1 and 99
   ```
   - Ensure `instance_count` is within the valid range (1-99)

2. **Subnet Distribution Issues**
   - Provide at least one subnet in `subnet_ids`
   - Instances are distributed using modulo: `instance_count % len(subnet_ids)`

3. **IAM Instance Profile Required**
   ```
   Error: iam_instance_profile is required
   ```
   - CIS compliance requires IAM instance profile for all EC2 instances
   - Create an IAM role and instance profile before deployment

4. **KMS Key Permissions**
   - Ensure EC2 service has permission to use specified KMS keys
   - Use `alias/aws/ebs` for default AWS-managed encryption

### Getting Help

For additional support:
- Review module examples in `modules/ec2/examples/`
- Check AWS documentation for instance types and AMI requirements
- Validate security group and subnet configurations
- Ensure IAM permissions for EC2, EBS, and KMS services

---

## Version History

- **v1.0.0** - Initial implementation

## Related Modules

- **[modules/security-group](../security-group/)** - Security group management
- **[modules/s3](../s3/)** - S3 bucket configuration  
- **[modules/ssm](../ssm/)** - Systems Manager parameters
- **[modules/alb](../alb/)** - Application Load Balancer
- **[modules/acm](../acm/)** - SSL/TLS certificates
