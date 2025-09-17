provider "aws" {
  region = "us-east-1"
}

# This S3 bucket will violate the tagging policy
resource "aws_s3_bucket" "test" {
  bucket = "my-policy-test-bucket"
  
  tags = {
    Name = "Test Bucket"
    # Missing: Environment, Owner, CostCenter, Project
  }
}

# This security group will violate the SSH policy
resource "aws_security_group_rule" "bad_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]  # SSH open to world!
  security_group_id = "sg-12345"
}

# This instance will violate cost control policy
resource "aws_instance" "expensive" {
  ami           = "ami-12345"
  instance_type = "x1.32xlarge"  # Very expensive!
  
  tags = {
    Environment = "dev"  # Dev shouldn't use x1 instances
  }
}
