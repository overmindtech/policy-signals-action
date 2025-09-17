# Security Group Policy
# Enforces security best practices for AWS Security Groups

package terraform.security

import input.resource_changes

# Deny SSH access from anywhere (0.0.0.0/0)
deny contains msg if {
    resource := resource_changes[_]
    resource.type == "aws_security_group_rule"
    resource.change.actions[_] == "create"
    
    # Check for SSH port (22)
    resource.change.after.from_port <= 22
    resource.change.after.to_port >= 22
    
    # Check for open to world
    resource.change.after.cidr_blocks[_] == "0.0.0.0/0"
    
    msg := sprintf("Security group rule '%s' allows SSH (port 22) from anywhere (0.0.0.0/0)", 
        [resource.address])
}

# Deny RDP access from anywhere
deny contains msg if {
    resource := resource_changes[_]
    resource.type == "aws_security_group_rule"
    resource.change.actions[_] == "create"
    
    # Check for RDP port (3389)
    resource.change.after.from_port <= 3389
    resource.change.after.to_port >= 3389
    
    # Check for open to world
    resource.change.after.cidr_blocks[_] == "0.0.0.0/0"
    
    msg := sprintf("Security group rule '%s' allows RDP (port 3389) from anywhere (0.0.0.0/0)", 
        [resource.address])
}

# Warn about database ports open to internet
warn contains msg if {
    resource := resource_changes[_]
    resource.type == "aws_security_group_rule"
    resource.change.actions[_] == "create"
    
    # Common database ports
    database_ports := [3306, 5432, 1433, 27017, 6379, 9200, 5984]
    resource.change.after.from_port <= database_ports[_]
    resource.change.after.to_port >= database_ports[_]
    
    # Check for open to world
    resource.change.after.cidr_blocks[_] == "0.0.0.0/0"
    
    msg := sprintf("Security group rule '%s' exposes database ports to the internet", 
        [resource.address])
}

# Deny overly permissive egress rules
deny contains msg if {
    resource := resource_changes[_]
    resource.type == "aws_security_group_rule"
    resource.change.actions[_] == "create"
    resource.change.after.type == "egress"
    
    # Check for all protocols
    resource.change.after.protocol == "-1"
    resource.change.after.from_port == 0
    resource.change.after.to_port == 0
    
    msg := sprintf("Security group rule '%s' allows all egress traffic - be more specific", 
        [resource.address])
}
