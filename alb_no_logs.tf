resource "aws_lb" "application_no_logs" {
  load_balancer_type               = "${var.load_balancer_type}"
  name                             = "${var.load_balancer_name}"
  internal                         = "${var.load_balancer_is_internal}"
  security_groups                  = ["${var.security_groups}"]
  subnets                          = ["${var.subnets}"]
  idle_timeout                     = "${var.idle_timeout}"
  enable_cross_zone_load_balancing = "${var.enable_cross_zone_load_balancing}"
  enable_deletion_protection       = "${var.enable_deletion_protection}"
  enable_http2                     = "${var.enable_http2}"
  ip_address_type                  = "${var.ip_address_type}"
  tags                             = "${merge(var.tags, map("Name", var.load_balancer_name))}"

  timeouts {
    create = "${var.load_balancer_create_timeout}"
    delete = "${var.load_balancer_delete_timeout}"
    update = "${var.load_balancer_update_timeout}"
  }

  count      = "${var.load_balancer_type == "application" && !(var.logging_enabled)? 1 : 0}"
}

resource "aws_lb" "network_no_logs" {
  load_balancer_type               = "${var.load_balancer_type}"
  name                             = "${var.load_balancer_name}"
  internal                         = "${var.load_balancer_is_internal}"
  subnets                          = ["${var.subnets}"]
  idle_timeout                     = "${var.idle_timeout}"
  enable_cross_zone_load_balancing = "${var.enable_cross_zone_load_balancing}"
  enable_deletion_protection       = "${var.enable_deletion_protection}"
  enable_http2                     = "${var.enable_http2}"
  ip_address_type                  = "${var.ip_address_type}"
  tags                             = "${merge(var.tags, map("Name", var.load_balancer_name))}"

  timeouts {
    create = "${var.load_balancer_create_timeout}"
    delete = "${var.load_balancer_delete_timeout}"
    update = "${var.load_balancer_update_timeout}"
  }

  count      = "${var.load_balancer_type == "network" && !var.logging_enabled? 1 : 0}"
}


resource "aws_lb_target_group" "main_no_logs" {
  name                 = "${lookup(var.target_groups[count.index], "name")}"
  vpc_id               = "${var.vpc_id}"
  port                 = "${lookup(var.target_groups[count.index], "backend_port")}"
  protocol             = "${upper(lookup(var.target_groups[count.index], "backend_protocol"))}"
  deregistration_delay = "${lookup(var.target_groups[count.index], "deregistration_delay", lookup(local.target_groups_defaults, "deregistration_delay"))}"
  target_type          = "${lookup(var.target_groups[count.index], "target_type", lookup(local.target_groups_defaults, "target_type"))}"
  slow_start           = "${lookup(var.target_groups[count.index], "slow_start", lookup(local.target_groups_defaults, "slow_start"))}"

  health_check {
    interval            = "${lookup(var.target_groups[count.index], "health_check_interval", lookup(local.target_groups_defaults, "health_check_interval"))}"
    path                = "${lookup(var.target_groups[count.index], "health_check_path", lookup(local.target_groups_defaults, "health_check_path"))}"
    port                = "${lookup(var.target_groups[count.index], "health_check_port", lookup(local.target_groups_defaults, "health_check_port"))}"
    healthy_threshold   = "${lookup(var.target_groups[count.index], "health_check_healthy_threshold", lookup(local.target_groups_defaults, "health_check_healthy_threshold"))}"
    unhealthy_threshold = "${lookup(var.target_groups[count.index], "health_check_unhealthy_threshold", lookup(local.target_groups_defaults, "health_check_unhealthy_threshold"))}"
    timeout             = "${lookup(var.target_groups[count.index], "health_check_timeout", lookup(local.target_groups_defaults, "health_check_timeout"))}"
    protocol            = "${upper(lookup(var.target_groups[count.index], "healthcheck_protocol", lookup(var.target_groups[count.index], "backend_protocol")))}"
    matcher             = "${lookup(var.target_groups[count.index], "health_check_matcher", lookup(local.target_groups_defaults, "health_check_matcher"))}"
  }

  stickiness {
    type            = "lb_cookie"
    cookie_duration = "${lookup(var.target_groups[count.index], "cookie_duration", lookup(local.target_groups_defaults, "cookie_duration"))}"
    enabled         = "${lookup(var.target_groups[count.index], "stickiness_enabled", lookup(local.target_groups_defaults, "stickiness_enabled"))}"
  }

  tags       = "${merge(var.tags, map("Name", lookup(var.target_groups[count.index], "name")))}"
  count      = "${!(var.load_balancer_type == "application" || var.logging_enabled)? 0 : var.target_groups_count}"
  depends_on = ["aws_lb.application_no_logs"]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "frontend_http_tcp_no_logs" {
  load_balancer_arn = "${element(concat(aws_lb.application_no_logs.*.arn, list("")), 0)}"
  port              = "${lookup(var.http_tcp_listeners[count.index], "port")}"
  protocol          = "${lookup(var.http_tcp_listeners[count.index], "protocol")}"
  count             = "${!(var.load_balancer_type == "application" || var.logging_enabled)? 0 : var.http_tcp_listeners_count}"

  default_action {
    target_group_arn = "${aws_lb_target_group.main_no_logs.*.id[lookup(var.http_tcp_listeners[count.index], "target_group_index", 0)]}"
    type             = "forward"
  }
}

resource "aws_lb_listener" "frontend_https_no_logs" {
  load_balancer_arn = "${element(concat(aws_lb.application_no_logs.*.arn, list("")), 0)}"
  port              = "${lookup(var.https_listeners[count.index], "port")}"
  protocol          = "HTTPS"
  certificate_arn   = "${lookup(var.https_listeners[count.index], "certificate_arn")}"
  ssl_policy        = "${lookup(var.https_listeners[count.index], "ssl_policy", var.listener_ssl_policy_default)}"
  count             = "${!(var.load_balancer_type == "application" || var.logging_enabled)? 0 : var.https_listeners_count}"

  default_action {
    target_group_arn = "${aws_lb_target_group.main_no_logs.*.id[lookup(var.https_listeners[count.index], "target_group_index", 0)]}"
    type             = "forward"
  }
}

resource "aws_lb_listener_certificate" "https_listener_no_logs" {
  listener_arn    = "${aws_lb_listener.frontend_https_no_logs.*.arn[lookup(var.extra_ssl_certs[count.index], "https_listener_index")]}"
  certificate_arn = "${lookup(var.extra_ssl_certs[count.index], "certificate_arn")}"
  count           = "${!(var.load_balancer_type == "application" || var.logging_enabled)? 0 : var.extra_ssl_certs_count}"
}

##### Network LB

resource "aws_lb_target_group" "main_no_logs_nw_lb" {
  name                 = "${lookup(var.target_groups[count.index], "name")}"
  vpc_id               = "${var.vpc_id}"
  port                 = "${lookup(var.target_groups[count.index], "backend_port")}"
  protocol             = "${upper(lookup(var.target_groups[count.index], "backend_protocol"))}"
  deregistration_delay = "${lookup(var.target_groups[count.index], "deregistration_delay", lookup(local.target_groups_defaults, "deregistration_delay"))}"
  target_type          = "${lookup(var.target_groups[count.index], "target_type", lookup(local.target_groups_defaults, "target_type"))}"
  slow_start           = "${lookup(var.target_groups[count.index], "slow_start", lookup(local.target_groups_defaults, "slow_start"))}"

  health_check {
    interval            = "${lookup(var.target_groups[count.index], "health_check_interval", lookup(local.target_groups_defaults, "health_check_interval"))}"
    port                = "${lookup(var.target_groups[count.index], "health_check_port", lookup(local.target_groups_defaults, "health_check_port"))}"
    healthy_threshold   = "${lookup(var.target_groups[count.index], "health_check_healthy_threshold", lookup(local.target_groups_defaults, "health_check_healthy_threshold"))}"
    unhealthy_threshold = "${lookup(var.target_groups[count.index], "health_check_unhealthy_threshold", lookup(local.target_groups_defaults, "health_check_unhealthy_threshold"))}"
    protocol            = "${upper(lookup(var.target_groups[count.index], "healthcheck_protocol", lookup(var.target_groups[count.index], "backend_protocol")))}"
  }

  tags       = "${merge(var.tags, map("Name", lookup(var.target_groups[count.index], "name")))}"
  count      = "${!(var.load_balancer_type == "network" || var.logging_enabled) ? 0 : var.target_groups_count}"
  depends_on = ["aws_lb.application_no_logs"]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "frontend_http_tcp_no_logs_nw_lb" {
  load_balancer_arn = "${element(concat(aws_lb.application_no_logs.*.arn, list("")), 0)}"
  port              = "${lookup(var.http_tcp_listeners[count.index], "port")}"
  protocol          = "${lookup(var.http_tcp_listeners[count.index], "protocol")}"
  count             = "${!(var.load_balancer_type == "network" || var.logging_enabled) ? 0 : var.http_tcp_listeners_count}"

  default_action {
    target_group_arn = "${aws_lb_target_group.main_no_logs_nw_lb.*.id[lookup(var.http_tcp_listeners[count.index], "target_group_index", 0)]}"
    type             = "forward"
  }
}

resource "aws_lb_listener" "frontend_https_tcp_no_logs_nw_lb" {
  load_balancer_arn = "${element(concat(aws_lb.application_no_logs.*.arn, list("")), 0)}"
  port              = "${lookup(var.https_listeners[count.index], "port")}"
  protocol          = "${lookup(var.https_listeners[count.index], "protocol")}"
  count             = "${!(var.load_balancer_type == "network" || var.logging_enabled) ? 0 : var.https_listeners_count}"

  default_action {
    target_group_arn = "${aws_lb_target_group.main_no_logs_nw_lb.*.id[lookup(var.https_listeners[count.index], "target_group_index", 0)]}"
    type             = "forward"
  }
}

resource "aws_lb_listener_certificate" "https_listener_tcp_no_logs_nw_lb" {
  listener_arn    = "${aws_lb_listener.frontend_https_tcp_no_logs_nw_lb.*.arn[lookup(var.extra_ssl_certs[count.index], "https_listener_index")]}"
  certificate_arn = "${lookup(var.extra_ssl_certs[count.index], "certificate_arn")}"
  count           = "${!(var.load_balancer_type == "network" || var.logging_enabled) ? 0 : var.extra_ssl_certs_count}"
}
