# terraform/modules/alb/main.tf

# --- CloudFront Managed Prefix List ---
data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

# --- Security Group: CloudFront only ---
resource "aws_security_group" "alb" {
  name_prefix = "${var.name}-alb-"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-alb-sg" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "alb_from_cloudfront" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  prefix_list_ids   = [data.aws_ec2_managed_prefix_list.cloudfront.id]
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
}

# --- ALB ---
resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  idle_timeout = 300

  enable_deletion_protection = true
}

# --- Target Groups ---
resource "aws_lb_target_group" "api" {
  name        = "${var.name}-api"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/healthz"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 5
  }
}

resource "aws_lb_target_group" "frontend" {
  name        = "${var.name}-frontend"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/nginx-health"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 5
  }
}

# --- HTTPS Listener ---
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type = "authenticate-cognito"

    authenticate_cognito {
      user_pool_arn       = var.cognito_user_pool_arn
      user_pool_client_id = var.cognito_client_id
      user_pool_domain    = var.cognito_domain
    }

    order = 1
  }

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn

    order = 2
  }
}

# --- Listener Rules ---
# Health endpoints bypass Cognito auth
resource "aws_lb_listener_rule" "health_bypass" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10

  condition {
    path_pattern {
      values = ["/healthz", "/readyz"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

# API routes → API server (with Cognito)
resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }

  action {
    type = "authenticate-cognito"

    authenticate_cognito {
      user_pool_arn       = var.cognito_user_pool_arn
      user_pool_client_id = var.cognito_client_id
      user_pool_domain    = var.cognito_domain
    }

    order = 1
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn

    order = 2
  }
}
