# AWS Basic Infrastructure with Terraform
#
# Details:
#
# This Terraform configuration sets up a AWS infrastructure that includes:
#
# 1 VPC with public subnets in multiple AZs
# 1 Internet Gateway
# 1 Route Table associated with the public subnets
# 2 Security Groups: one for EC2 instances allowing SSH and HTTP access, another for Load Balancer allowing HTTP access
# 2 EC2 Instances running nginx in different subnets
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

# Create a VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "main-vpc"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

####################### SUBNET SETUP ########################

# Create Subnets in different AZs for high availability
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-2"
  }
}

####################### ROUTE TABLE SETUP ########################

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

# Associate Route Table with Subnets
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

####################### SECURITY GROUP SETUP ########################

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

# Security Group for Load Balancer
resource "aws_security_group" "lb" {
  name        = "lb-sg"
  description = "Allow HTTP traffic to load balancer"
  vpc_id      = aws_vpc.main.id

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
    Name = "lb-sg"
  }
}

####################### LOAD BALANCER SETUP ########################

# Application Load Balancer
resource "aws_lb" "nginx_lb" {
  name               = "nginx-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  tags = {
    Name = "nginx-load-balancer"
  }
}

# Target Group
resource "aws_lb_target_group" "nginx_tg" {
  name     = "nginx-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    interval            = 30
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "nginx-target-group"
  }
}

# Listener
resource "aws_lb_listener" "nginx_listener" {
  load_balancer_arn = aws_lb.nginx_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx_tg.arn
  }
}

####################### EC2 INSTANCE SETUP ########################

# EC2 Instances
resource "aws_instance" "nginx_1" {
  ami                    = "ami-0360c520857e3138f"      # Ubuntu 22.04 LTS
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public_1.id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = var.ssh_key_name

  # User data to install nginx
  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y nginx
              systemctl start nginx
              systemctl enable nginx
              echo "<h1>Hello from Terraform - Instance 1!</h1>" > /var/www/html/index.html
              EOF

  tags = {
    Name = "my-ec2-instance-1"
  }
}

resource "aws_instance" "nginx_2" {
  ami                    = "ami-0360c520857e3138f"  # Ubuntu 22.04 LTS
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public_2.id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = var.ssh_key_name 

  # User data to install nginx
  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y nginx
              systemctl start nginx
              systemctl enable nginx
              echo "<h1>Hello from Terraform - Instance 2!</h1>" > /var/www/html/index.html
              EOF

  tags = {
    Name = "my-ec2-instance-2"
  }
}

# Target Group Attachments
resource "aws_lb_target_group_attachment" "nginx_1" {
  target_group_arn = aws_lb_target_group.nginx_tg.arn
  target_id        = aws_instance.nginx_1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "nginx_2" {
  target_group_arn = aws_lb_target_group.nginx_tg.arn
  target_id        = aws_instance.nginx_2.id
  port             = 80
}

# Output the connection info
output "load_balancer_dns" {
  value = aws_lb.nginx_lb.dns_name
}

output "instance_1_public_ip" {
  value = aws_instance.nginx_1.public_ip
}

output "instance_2_public_ip" {
  value = aws_instance.nginx_2.public_ip
}

output "ssh_command_instance_1" {
  value = "ssh -i ${var.private_key_path} ubuntu@${aws_instance.nginx_1.public_ip}"
}

output "ssh_command_instance_2" {
  value = "ssh -i ${var.private_key_path} ubuntu@${aws_instance.nginx_2.public_ip}"
}

output "web_url_lb" {
  value = "http://${aws_lb.nginx_lb.dns_name}"
}

output "web_url_instance_1" {
  value = "http://${aws_instance.nginx_1.public_ip}"
}

output "web_url_instance_2" {
  value = "http://${aws_instance.nginx_2.public_ip}"
}
