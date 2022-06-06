data "aws_subnet_ids" "example" {
  vpc_id = var.vpc_id
}

resource "aws_lb" "front_end" {
  name               = "test-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.security_group]
  subnets            = data.aws_subnet_ids.example.ids

  enable_deletion_protection = true

#  access_logs {
#    bucket  = "sysops-soa-co2-zahos"
#    prefix  = "test-lb"
#    enabled = true
#  }

  tags = {
    Environment = "dev"
  }
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.front_end.arn
  port              = "5000"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = var.aws_lb_target_group_arn
  }
}

