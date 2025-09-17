# S3 Bucket Tagging Policy
# Ensures all S3 buckets have required tags for governance and cost tracking

package terraform.s3

import input.resource_changes

required_tags := {"Environment", "Owner", "CostCenter", "Project"}

# Check S3 buckets for missing required tags
deny contains msg if {
    resource := resource_changes[_]
    resource.type == "aws_s3_bucket"
    resource.change.actions[_] == "create"
    
    provided_tags := object.get(resource.change.after, "tags", {})
    missing_tags := required_tags - object.keys(provided_tags)
    count(missing_tags) > 0
    
    msg := sprintf("S3 bucket '%s' is missing required tags: %v", 
        [resource.address, missing_tags])
}

# Ensure S3 buckets are encrypted
deny contains msg if {
    resource := resource_changes[_]
    resource.type == "aws_s3_bucket"
    resource.change.actions[_] == "create"
    
    # Check if server_side_encryption_configuration is set
    encryption := object.get(resource.change.after, "server_side_encryption_configuration", [])
    count(encryption) == 0
    
    msg := sprintf("S3 bucket '%s' does not have encryption enabled", 
        [resource.address])
}

# Warn about public S3 buckets
warn contains msg if {
    resource := resource_changes[_]
    resource.type == "aws_s3_bucket_public_access_block"
    resource.change.actions[_] == "create"
    
    # Check if any public access is allowed
    resource.change.after.block_public_acls == false
    
    msg := sprintf("S3 bucket '%s' allows public ACLs - ensure this is intended", 
        [resource.address])
}
