variable "aws_region" {
  description = "AWS region to deploy resources."
  type        = string
  default     = "us-east-1"
}

variable "env_name" {
  description = "Environment name (e-.g., uat, prod)."
  type        = string
}

variable "alb_security_groups" {
  description = "List of security group IDs for the ALB."
  type        = list(string)
}

variable "alb_subnets" {
  description = "List of subnet IDs for the ALB."
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC ID in which to deploy resources."
  type        = string
}

variable "asg_subnets" {
  description = "List of subnet IDs for the Auto Scaling Group."
  type        = list(string)
}

variable "asg_min_size" {
  description = "Minimum size of the Auto Scaling Group."
  type        = number
}

variable "asg_max_size" {
  description = "Maximum size of the Auto Scaling Group."
  type        = number
}

variable "asg_desired_capacity" {
  description = "Desired capacity of the Auto Scaling Group."
  type        = number
}

variable "launch_template_id" {
  description = "Launch Template ID to be used by the Auto Scaling Group."
  type        = string
}
