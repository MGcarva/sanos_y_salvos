# ================================================================
# ALB — Application Load Balancer
# Punto de entrada único desde internet
# Distribuye tráfico entre frontend y bff-service
# ================================================================

resource "aws_lb" "main" {
  name               = "${var.proyecto}-alb"
  internal           = false   # Público — accesible desde internet
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.publica_az_a.id, aws_subnet.publica_az_b.id]

  enable_deletion_protection = false   # Permite terraform destroy sin bloqueo

  tags = {
    Name     = "${var.proyecto}-alb"
    Proyecto = var.proyecto
    Ambiente = var.ambiente
  }
}

# ================================================================
# TARGET GROUP: FRONTEND (puerto 3000)
# El ALB envía peticiones de raíz "/" aquí
# ================================================================

resource "aws_lb_target_group" "frontend" {
  name        = "${var.proyecto}-tg-frontend"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name     = "${var.proyecto}-tg-frontend"
    Proyecto = var.proyecto
  }
}

# ================================================================
# TARGET GROUP: BFF SERVICE (puerto 8080)
# El ALB envía peticiones de "/api/*" aquí
# ================================================================

resource "aws_lb_target_group" "bff" {
  name        = "${var.proyecto}-tg-bff"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/api/actuator/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name     = "${var.proyecto}-tg-bff"
    Proyecto = var.proyecto
  }
}

# ================================================================
# LISTENER HTTP puerto 80
# Reglas de ruteo:
#   /api/*  → bff-service  (microservicios Java)
#   /*      → frontend     (Next.js — regla por defecto)
# ================================================================

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  # Acción por defecto: redirigir al frontend en S3
  default_action {
    type = "redirect"
    redirect {
      host        = "${var.proyecto}-frontend-${data.aws_caller_identity.current.account_id}.s3-website-us-east-1.amazonaws.com"
      path        = "/#{path}"
      query       = "#{query}"
      protocol    = "HTTP"
      port        = "80"
      status_code = "HTTP_302"
    }
  }
}

# Regla: /api/* → bff-service
resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.bff.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}
