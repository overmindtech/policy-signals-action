# Cost Control Policy
# Enforces instance type and resource sizing limits to control costs

package terraform.cost

import input.resource_changes

# Define allowed instance types for different environments
dev_instance_types := ["t3.micro", "t3.small", "t3.medium", "t2.micro", "t2.small"]
staging_instance_types := ["t3.medium", "t3.large", "m5.large", "m5.xlarge"]
prod_instance_types := ["t3.large", "t3.xlarge", "m5.large", "m5.xlarge", "m5.2xlarge", "c5.xlarge", "c5.2xlarge"]

# Deny non-approved instance types based on environment
deny contains msg if {
    resource := resource_changes[_]
    resource.type == "aws_instance"
    resource.change.actions[_] == "create"
    
    # Get environment tag
    tags := object.get(resource.change.after, "tags", {})
    env := lower(object.get(tags, "Environment", "dev"))
    
    # Check instance type based on environment
    instance_type := resource.change.after.instance_type
    env == "dev"
    not instance_type in dev_instance_types
    
    msg := sprintf("EC2 instance '%s' uses non-approved instance type '%s' for dev environment. Allowed types: %v", 
        [resource.address, instance_type, dev_instance_types])
}

deny contains msg if {
    resource := resource_changes[_]
    resource.type == "aws_instance"
    resource.change.actions[_] == "create"
    
    tags := object.get(resource.change.after, "tags", {})
    env := lower(object.get(tags, "Environment", "staging"))
    
    instance_type := resource.change.after.instance_type
    env == "staging"
    not instance_type in staging_instance_types
    
    msg := sprintf("EC2 instance '%s' uses non-approved instance type '%s' for staging environment. Allowed types: %v", 
        [resource.address, instance_type, staging_instance_types])
}

# Warn about expensive instance types
warn contains msg if {
    resource := resource_changes[_]
    resource.type == "aws_instance"
    resource.change.actions[_] == "create"
    
    expensive_types := ["x1", "x2", "p3", "p4", "g4", "g5", "f1", "h1", "i3", "i4"]
    instance_family := split(resource.change.after.instance_type, ".")[0]
    
    instance_family in expensive_types
    
    msg := sprintf("EC2 instance '%s' uses expensive instance type '%s' - ensure this is necessary", 
        [resource.address, resource.change.after.instance_type])
}

# Deny RDS instances without multi-AZ in production
deny contains msg if {
    resource := resource_changes[_]
    resource.type == "aws_db_instance"
    resource.change.actions[_] == "create"
    
    tags := object.get(resource.change.after, "tags", {})
    env := lower(object.get(tags, "Environment", ""))
    
    env == "prod"
    resource.change.after.multi_az == false
    
    msg := sprintf("RDS instance '%s' in production must have Multi-AZ enabled for high availability", 
        [resource.address])
}

# Warn about provisioned IOPS volumes
warn contains msg if {
    resource := resource_changes[_]
    resource.type == "aws_ebs_volume"
    resource.change.actions[_] == "create"
    
    resource.change.after.type == "io1"
    
    msg := sprintf("EBS volume '%s' uses provisioned IOPS (io1) which incurs additional charges", 
        [resource.address])
}
