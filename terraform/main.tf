terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
  # Optionally, configure a backend for remote state storage (e.g., S3 + DynamoDB lock).
}

provider "aws" {
  region = var.aws_region
}

# Application Load Balancer
resource "aws_lb" "oauth_alb" {
  name               = "${var.env_name}-oauth-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = var.alb_security_groups
  subnets            = var.alb_subnets

  idle_timeout               = 60
  enable_deletion_protection = false
}

# Target Group for OAuth Service
resource "aws_lb_target_group" "oauth_tg" {
  name     = "${var.env_name}-oauth-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Auto Scaling Group (ASG)
resource "aws_autoscaling_group" "oauth_asg" {
  name                      = "${var.env_name}-oauth-asg"
  max_size                  = var.asg_max_size
  min_size                  = var.asg_min_size
  desired_capacity          = var.asg_desired_capacity
  vpc_zone_identifier       = var.asg_subnets
  health_check_type         = "EC2"
  health_check_grace_period = 300

  # Using an existing launch template (managed outside Terraform) via variable
  launch_template {
    id      = var.launch_template_id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.oauth_tg.arn]

  tag {
    key                 = "Name"
    value               = "${var.env_name}-oauth-instance"
    propagate_at_launch = true
  }
}

# Scaling Policy: Increase capacity if CPU is high
resource "aws_autoscaling_policy" "scale_out" {
  name                   = "${var.env_name}-scale-out"
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1       # Increase capacity by 1 instance
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.oauth_asg.name
}

# CloudWatch Alarm: Trigger scaling when average CPU > 50%
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.env_name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 50
  alarm_description   = "Alarm when average CPU utilization exceeds 50% for 10 minutes."
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.oauth_asg.name
  }
  alarm_actions = [aws_autoscaling_policy.scale_out.arn]
}

