terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ca-central-1"
}

# Define variables for VPC and security group
variable "vpc_id" {
  description = "ID of the VPC where the security group will be created."
}

variable "subnet1_id" {
  description = "ID of the subnet 1."
}

variable "subnet2_id" {
  description = "ID of the subnet 2."
}

# Create an S3 Bucket
resource "aws_s3_bucket" "my_bucket" {
  bucket = "my-S3-Bucket"
  acl    = "private"
}

# Create an IAM Role
resource "aws_iam_role" "my_role" {
  name = "myS3Role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "glue.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# Create an IAM Policy
resource "aws_iam_policy" "my_policy" {
  name = "my-policy-name"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::my-S3-Bucke/*"
    }
  ]
}
EOF
}

# Attache Policy to role
resource "aws_iam_policy_attachment" "attach_policy" {
  policy_arn = aws_iam_policy.my_policy.arn
  roles      = [aws_iam_role.my_role.name]
}

# Create a Security Group with Port 3306 open for 0.0.0.0/0
resource "aws_security_group" "my_security_group" {
  name        = "mySQLSG"
  description = "Security group for RDS"
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  vpc_id = var.vpc_id     # Passed through command line
}

# Create an RDS Instance with MySQL and use the SG created above
resource "aws_db_instance" "my_rds_instance" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t2.micro"
  name                 = "mydb"
  username             = "admin"
  password             = "metro1234"
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true
  vpc_security_group_ids = [aws_security_group.my_security_group.id]
  tags = {
    Name = "My RDS Instance"
  }
}

# Create an AWS Glue Job
resource "aws_glue_job" "my_glue_job" {
  name     = "myGlueJob"
  role_arn = aws_iam_role.my_role.arn
  command {
    script_location = "s3://my-unique-bucket-name/path/to/your/glue/script.py"
  }
}

# Create a KMS Key
resource "aws_kms_key" "my_kms_key" {
  description             = "My KMS Key"
  deletion_window_in_days = 30
}

# Create an Application Load Balancer
resource "aws_lb" "my_alb" {
  name               = "my-alb"
  internal           = false
  load_balancer_type = "application"
  enable_deletion_protection = false
  subnets            = [var.subnet1_id, var.subnet2_id]
}

# Create an Auto Scaling Group (ASG)
resource "aws_autoscaling_group" "my_asg" {
  name                 = "my-asg"
  max_size             = 3
  min_size             = 1
  desired_capacity     = 2
  launch_template {
    id      = aws_launch_template.my_launch_template.id
    version = "$Latest"
  }
}
