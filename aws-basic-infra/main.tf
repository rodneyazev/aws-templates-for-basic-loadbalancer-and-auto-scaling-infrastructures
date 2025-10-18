# AWS Basic Infrastructure with Terraform
#
# Details:
#
# This Terraform configuration sets up a AWS infrastructure that includes:
#
# 1 VPC with a public subnet
# 1 Internet Gateway
# 1 Route Table associated with the public subnet
# 1 Security Group allowing SSH and HTTP access
# 1 EC2 Instance running nginx
#
## Note: Replace the AMI ID with a valid one for your AWS region.
## Also, ensure you have an existing SSH key pair in AWS or create one using the commented-out resource.
#

# Provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

######################### VPC SETUP ########################

# Create a VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "main-vpc"
  }
}

################### INTERNET GATEWAY SETUP #################

# Create Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

####################### SUBNET SETUP ########################

# Create Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet"
  }
}

###################### ROUTE TABLE SETUP ####################

# Create Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public-rt"
  }
}

# Associate Route Table with Subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

#################### SECURITY GROUP SETUP ####################

# Security Group - Allow SSH and HTTP
resource "aws_security_group" "web" {
  name        = "nginx-sg"
  description = "Allow SSH and HTTP traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "nginx-sg"
  }
}

######################### EC2 INSTANCE SETUP ########################

# EC2 Instance
resource "aws_instance" "nginx" {
  ami                    = "ami-0360c520857e3138f"      # Ubuntu 22.04 LTS
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = var.ssh_key_name               # Using existing key pair name directly
  #key_name              = aws_key_pair.deployer.key_name # Now using the key pair resource

  # User data to install nginx
  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y nginx
              systemctl start nginx
              systemctl enable nginx
              echo "<h1>Hello from Terraform!</h1>" > /var/www/html/index.html
              EOF

  tags = {
    Name = "my-ec2-instance"
  }
}

# Output the connection info
output "public_ip" {
  value = aws_instance.nginx.public_ip
}

output "ssh_command" {
  value = "ssh -i ${var.private_key_path} ubuntu@${aws_instance.nginx.public_ip}"
}

output "web_url" {
  value = "http://${aws_instance.nginx.public_ip}"
}
