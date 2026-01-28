# -----------------------------------------------------------------------------
# VPC ネットワーク
# -----------------------------------------------------------------------------
resource "google_compute_network" "vpc" {
  name                    = "wiz-dev-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

# -----------------------------------------------------------------------------
# パブリックサブネット（インターネットアクセス可能）
# -----------------------------------------------------------------------------
resource "google_compute_subnetwork" "public_1" {
  name          = "wiz-dev-public-subnet-1"
  ip_cidr_range = "10.30.1.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
}

resource "google_compute_subnetwork" "public_2" {
  name          = "wiz-dev-public-subnet-2"
  ip_cidr_range = "10.30.2.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
}

# -----------------------------------------------------------------------------
# プライベートサブネット（NAT 経由でインターネットアクセス）
# -----------------------------------------------------------------------------
resource "google_compute_subnetwork" "private_1" {
  name                     = "wiz-dev-private-subnet-1"
  ip_cidr_range            = "10.30.101.0/24"
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true
}

resource "google_compute_subnetwork" "private_2" {
  name                     = "wiz-dev-private-subnet-2"
  ip_cidr_range            = "10.30.102.0/24"
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true
}

# -----------------------------------------------------------------------------
# Cloud Router（NAT 用）
# -----------------------------------------------------------------------------
resource "google_compute_router" "nat_router" {
  name    = "wiz-dev-nat-router"
  region  = var.region
  network = google_compute_network.vpc.id

  bgp {
    asn = 64514
  }
}

# -----------------------------------------------------------------------------
# Cloud NAT（プライベートサブネット用）
# -----------------------------------------------------------------------------
resource "google_compute_router_nat" "nat" {
  name                               = "wiz-dev-nat"
  router                             = google_compute_router.nat_router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# -----------------------------------------------------------------------------
# ファイアウォールルール（デフォルトの許可ルール）
# -----------------------------------------------------------------------------
# 内部通信を許可
resource "google_compute_firewall" "allow_internal" {
  name    = "wiz-dev-allow-internal"
  network = google_compute_network.vpc.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  source_ranges = [
    google_compute_subnetwork.public_1.ip_cidr_range,
    google_compute_subnetwork.public_2.ip_cidr_range,
    google_compute_subnetwork.private_1.ip_cidr_range,
    google_compute_subnetwork.private_2.ip_cidr_range,
  ]
}

# SSH を許可（必要に応じて制限）
resource "google_compute_firewall" "allow_ssh" {
  name    = "wiz-dev-allow-ssh"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ssh"]
}

# HTTP/HTTPS を許可（必要に応じて制限）
resource "google_compute_firewall" "allow_http_https" {
  name    = "wiz-dev-allow-http-https"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server", "https-server"]
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------
output "vpc_id" {
  value       = google_compute_network.vpc.id
  description = "VPC ネットワーク ID"
}

output "vpc_name" {
  value       = google_compute_network.vpc.name
  description = "VPC ネットワーク名"
}

output "public_subnet_ids" {
  value = [
    google_compute_subnetwork.public_1.id,
    google_compute_subnetwork.public_2.id,
  ]
  description = "パブリックサブネット ID のリスト"
}

output "private_subnet_ids" {
  value = [
    google_compute_subnetwork.private_1.id,
    google_compute_subnetwork.private_2.id,
  ]
  description = "プライベートサブネット ID のリスト"
}

output "public_subnet_names" {
  value = [
    google_compute_subnetwork.public_1.name,
    google_compute_subnetwork.public_2.name,
  ]
  description = "パブリックサブネット名のリスト"
}

output "private_subnet_names" {
  value = [
    google_compute_subnetwork.private_1.name,
    google_compute_subnetwork.private_2.name,
  ]
  description = "プライベートサブネット名のリスト"
}
