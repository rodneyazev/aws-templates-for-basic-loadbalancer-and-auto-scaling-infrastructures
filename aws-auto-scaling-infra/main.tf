# AWS Basic Infrastructure with Terraform
#
# Details:
#
# This Terraform configuration sets up a AWS infrastructure that includes:
#
# - A VPC with public subnets
# - An Internet Gateway
# - Route Tables and Associations
# - Security Groups for web servers and load balancer
# - An Application Load Balancer (ALB) with a target group and listener
# - An Auto Scaling Group (ASG) with a launch template to run Nginx web servers
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

####################### VPC SETUP ###########################

# Create a VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "main-vpc"
  }
}

############### INTERNET GATEWAY SETUP ######################

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

####################### AUTO SCALING SETUP ########################

# Launch Template for Auto Scaling Group
resource "aws_launch_template" "nginx_lt" {
  name_prefix   = "nginx-lt-"
  image_id      = "ami-0360c520857e3138f"       # Ubuntu 22.04 LTS
  instance_type = var.instance_type
  key_name      = var.ssh_key_name

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.web.id]
  }

user_data = base64encode(<<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y nginx
              systemctl start nginx
              systemctl enable nginx
              
              # Generate a simple unique identifier
              UNIQUE_ID=$(date +%s | md5sum | head -c 8)
              
              # Create HTML with unique ID
              cat > /var/www/html/index.html << EOL
              <!DOCTYPE html>
              <html>
              <head>
                  <title>Auto Scaling Instance</title>
                  <style>
                      body { font-family: Arial, sans-serif; margin: 40px; }
                      .instance { background: #f0f0f0; padding: 20px; border-radius: 5px; }
                  </style>
              </head>
              <body>
                  <h1>Hello from Auto Scaling Instance</h1>
                  <div class="instance">
                      <p><strong>Instance ID:</strong> $UNIQUE_ID</p>
                      <p><strong>Launched:</strong> $(date)</p>
                  </div>
                  <p>This instance is part of an Auto Scaling Group!</p>
              </body>
              </html>
              EOL
              EOF
)

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "nginx-auto-scaling-instance"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "nginx_asg" {
  name_prefix               = "nginx-asg-"
  desired_capacity          = 2
  max_size                  = 4
  min_size                  = 2
  health_check_grace_period = 300
  health_check_type         = "ELB"
  force_delete              = true
  vpc_zone_identifier       = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  target_group_arns         = [aws_lb_target_group.nginx_tg.arn]

  launch_template {
    id      = aws_launch_template.nginx_lt.id
    version = "$Latest"
  }

  # Instance refresh to update instances when launch template changes
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "my-asg-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = "production"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [load_balancers, target_group_arns]
  }
}

# Auto Scaling Policies
# Scale-up Policy
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "nginx-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.nginx_asg.name
}

# Scale-down Policy
resource "aws_autoscaling_policy" "scale_down" {
  name                   = "nginx-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.nginx_asg.name
}

# CloudWatch Alarms for Auto Scaling
# High CPU Alarm
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "nginx-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "70"
  alarm_description   = "This metric monitors EC2 CPU utilization"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.nginx_asg.name
  }
}

# Low CPU Alarm
resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "nginx-low-cpu"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "30"
  alarm_description   = "This metric monitors EC2 CPU utilization"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.nginx_asg.name
  }
}

# Output the connection info
output "load_balancer_dns" {
  value = aws_lb.nginx_lb.dns_name
}

output "web_url_lb" {
  value = "http://${aws_lb.nginx_lb.dns_name}"
}

output "auto_scaling_group_name" {
  value = aws_autoscaling_group.nginx_asg.name
}

output "launch_template_name" {
  value = aws_launch_template.nginx_lt.name
}

output "asg_desired_capacity" {
  value = aws_autoscaling_group.nginx_asg.desired_capacity
}

output "asg_min_size" {
  value = aws_autoscaling_group.nginx_asg.min_size
}

output "asg_max_size" {
  value = aws_autoscaling_group.nginx_asg.max_size
}

# Added SSH command output for instances created by auto scaling
output "ssh_command_example" {
  value = "ssh -i ${var.private_key_path} ubuntu@<instance-ip>"
}
