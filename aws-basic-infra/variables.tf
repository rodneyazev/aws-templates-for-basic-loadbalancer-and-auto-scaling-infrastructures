variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ssh_key_name" {
  description = "Name of the existing SSH key pair in AWS"
  type        = string
  default     = "my-ssh-key-votc"     # Name of the existing SSH key pair in AWS. The same you download or create in AWS EC2 console.
}

variable "private_key_path" {
  description = "Path to the private key file for SSH access"
  type        = string
  default     = "~/.aws/<your-ssh-key>.pem"                          # Example: "../.aws/my-ssh-key-votc.pem" or "~/.aws/my-ssh-key-votc.pem"
}
