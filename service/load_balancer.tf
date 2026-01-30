# -----------------------------------------------------------------------------
# Global HTTP(S) ロードバランサ
# Compute Engine (uso8-blog-03) の手前に配置。ポート 80 -> バックエンド 8080
# -----------------------------------------------------------------------------

# LB 用グローバル外部 IP
resource "google_compute_global_address" "lb" {
  name = "wiz-dev-blog-lb-ip"
}

# ヘルスチェック（アプリ 8080）
resource "google_compute_health_check" "blog" {
  name                = "wiz-dev-blog-hc"
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = 8080
    request_path = "/login"
  }
}

# Unmanaged Instance Group（1 台の VM を登録）
resource "google_compute_instance_group" "blog" {
  name        = "wiz-dev-blog-ig"
  zone        = "${var.region}-a"
  description = "Instance group for uso8-blog-03"

  named_port {
    name = "http8080"
    port = 8080
  }

  instances = [
    google_compute_instance.blog_app.self_link,
  ]
}

# バックエンドサービス
resource "google_compute_backend_service" "blog" {
  name                  = "wiz-dev-blog-backend"
  protocol              = "HTTP"
  port_name             = "http8080"
  timeout_sec           = 30
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group           = google_compute_instance_group.blog.id
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

  health_checks = [google_compute_health_check.blog.id]
}

# URL マップ（デフォルト -> バックエンド）
resource "google_compute_url_map" "blog" {
  name            = "wiz-dev-blog-url-map"
  default_service = google_compute_backend_service.blog.id
}

# Target HTTP Proxy
resource "google_compute_target_http_proxy" "blog" {
  name    = "wiz-dev-blog-http-proxy"
  url_map = google_compute_url_map.blog.id
}

# Global Forwarding Rule（外部 80 -> Proxy）
resource "google_compute_global_forwarding_rule" "blog_http" {
  name                  = "wiz-dev-blog-http"
  target                = google_compute_target_http_proxy.blog.id
  ip_address            = google_compute_global_address.lb.id
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
}

# ヘルスチェック用ファイアウォール（GCP 推奨）
resource "google_compute_firewall" "allow_lb_health_check" {
  name    = "wiz-dev-allow-lb-health-check"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = ["http-server", "https-server"]
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------
output "blog_lb_ip" {
  value       = google_compute_global_address.lb.address
  description = "ロードバランサの外部 IP（http://<this> でアプリへアクセス）"
}
