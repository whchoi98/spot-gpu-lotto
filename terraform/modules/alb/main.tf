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

resource "aws_security_group_rule" "alb_from_cloudfront_https" {
  count             = var.certificate_arn != "" ? 1 : 0
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  prefix_list_ids   = [data.aws_ec2_managed_prefix_list.cloudfront.id]
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_from_cloudfront_http" {
  count             = var.certificate_arn == "" ? 1 : 0
  type              = "ingress"
  from_port         = 80
  to_port           = 80
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

resource "aws_lb_target_group" "grafana" {
  name        = "${var.name}-grafana"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/grafana/api/health"
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

# --- HTTPS Listener (requires ACM certificate) ---
resource "aws_lb_listener" "https" {
  count             = var.certificate_arn != "" ? 1 : 0
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

# --- HTTP Listener (fallback when no certificate) ---
resource "aws_lb_listener" "http" {
  count             = var.certificate_arn == "" ? 1 : 0
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# Health endpoints (HTTP mode)
resource "aws_lb_listener_rule" "health_bypass_http" {
  count        = var.certificate_arn == "" ? 1 : 0
  listener_arn = aws_lb_listener.http[0].arn
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

# Grafana routes (HTTP mode — require origin-verify header from CloudFront)
resource "aws_lb_listener_rule" "grafana_http" {
  count        = var.certificate_arn == "" ? 1 : 0
  listener_arn = aws_lb_listener.http[0].arn
  priority     = 50

  condition {
    path_pattern {
      values = ["/grafana", "/grafana/*"]
    }
  }

  condition {
    http_header {
      http_header_name = "X-Origin-Verify"
      values           = [var.origin_verify_secret]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana.arn
  }
}

# API routes → API server (HTTP mode, no Cognito)
resource "aws_lb_listener_rule" "api_http" {
  count        = var.certificate_arn == "" ? 1 : 0
  listener_arn = aws_lb_listener.http[0].arn
  priority     = 100

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

# --- Listener Rules ---
# Health endpoints bypass Cognito auth
resource "aws_lb_listener_rule" "health_bypass" {
  count        = var.certificate_arn != "" ? 1 : 0
  listener_arn = aws_lb_listener.https[0].arn
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

# Grafana routes (HTTPS mode, with Cognito auth)
resource "aws_lb_listener_rule" "grafana_https" {
  count        = var.certificate_arn != "" ? 1 : 0
  listener_arn = aws_lb_listener.https[0].arn
  priority     = 50

  condition {
    path_pattern {
      values = ["/grafana", "/grafana/*"]
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
    target_group_arn = aws_lb_target_group.grafana.arn

    order = 2
  }
}

# API routes → API server (with Cognito)
resource "aws_lb_listener_rule" "api" {
  count        = var.certificate_arn != "" ? 1 : 0
  listener_arn = aws_lb_listener.https[0].arn
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
