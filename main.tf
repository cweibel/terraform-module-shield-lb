variable subnet_ids            {}  # The AWS Subnet Id to place the lb into
variable resource_tags         {}  # AWS tags to apply to resources
variable vpc_id                {}  # The VPC Id
variable shield_domain         {}  # url used for shield domain
variable route53_zone_id       {}  # Route53 zone id
variable security_groups       {}  # Array of security groups to use
variable shield_acm_arn        {}  # ACM arn for the shield certificates
variable internal_lb           { default = true } # Determine whether the load balancer is internal-only facing

variable enable_route_53       { default = 1 }  # Disable if using CloudFlare or other DNS


################################################################################
# S.H.I.E.L.D. ALB
################################################################################
resource "aws_lb" "shield_alb" {
  name               = "shield-alb"
  internal           = var.internal_lb
  load_balancer_type = "application"
  subnets            = var.subnet_ids
  security_groups    = var.security_groups
  tags               = merge({Name = "shield-alb"}, var.resource_tags)
}

################################################################################
# S.H.I.E.L.D. ALB Target Group
################################################################################
resource "aws_lb_target_group" "shield_alb_tg" {
  name     = "shield-alb-tg"
  port     = 443
  protocol = "HTTPS"
  vpc_id   = var.vpc_id
  tags     = merge({Name = "shield-alb-tg"}, var.resource_tags)
  health_check {
    path = "/"
    protocol = "HTTPS"
  }
}



################################################################################
# S.H.I.E.L.D. ALB Listeners - S.H.I.E.L.D. API - HTTPS
################################################################################
resource "aws_alb_listener" "shield_alb_listener_443" {
  load_balancer_arn = aws_lb.shield_alb.arn
  port = "443"
  protocol = "HTTPS"
  ssl_policy = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn = var.shield_acm_arn
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.shield_alb_tg.arn
  }
  tags = merge({Name = "shield-alb-listener-443"}, var.resource_tags)
}

################################################################################
# S.H.I.E.L.D. ALB Route53 DNS
################################################################################
resource "aws_route53_record" "shield_alb_record" {

  count   = var.enable_route_53
  zone_id = var.route53_zone_id
  name    = var.shield_domain
  type    = "CNAME"
  ttl     = "60"
  records = ["${aws_lb.shield_alb.dns_name}"]
}

output "dns_name" {value = aws_lb.shield_alb.dns_name}
output "lb_name"  {value = aws_lb.shield_alb.name }
output "lb_target_group_name" { value = aws_lb_target_group.shield_alb_tg.name }
