# -----------------------------------------------------------------------------
# Cloud SQL (PostgreSQL)
# プライベート IP で VPC 内から接続
# -----------------------------------------------------------------------------

# Service Networking API 有効化
resource "google_project_service" "servicenetworking" {
  project            = var.project_id
  service            = "servicenetworking.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "sqladmin" {
  project            = var.project_id
  service            = "sqladmin.googleapis.com"
  disable_on_destroy = false
}

# プライベート接続用 IP レンジ（VPC サブネット 10.30.1/2/101/102 と重複しない）
resource "google_compute_global_address" "private_ip_range" {
  name          = "wiz-dev-cloud-sql-private-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = "10.30.200.0"
  prefix_length = 24
  network       = google_compute_network.vpc.id

  depends_on = [google_project_service.servicenetworking]
}

# プライベートサービス接続
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]
}

# Cloud SQL (PostgreSQL) インスタンス
resource "google_sql_database_instance" "blog" {
  name             = "wiz-dev-blog-db"
  database_version = "POSTGRES_14"
  region           = var.region

  depends_on = [
    google_project_service.sqladmin,
    google_service_networking_connection.private_vpc_connection,
  ]

  settings {
    tier              = "db-f1-micro"
    availability_type = "ZONAL"
    disk_size         = 10
    disk_type         = "PD_SSD"

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.vpc.id
    }

    backup_configuration {
      enabled                        = true
      start_time                     = "03:00"
      point_in_time_recovery_enabled = false
      backup_retention_settings {
        retained_backups = 7
      }
    }

    maintenance_window {
      day          = 7
      hour         = 4
      update_track = "stable"
    }
  }

  deletion_protection = false
}

# データベース
resource "google_sql_database" "blogdb" {
  name     = "blogdb"
  instance = google_sql_database_instance.blog.name
}

# DB ユーザー（uso8）
# 初回 apply 後、Cloud Console > Cloud SQL > blogdb で postgres として以下を実行すること:
#   GRANT ALL ON SCHEMA public TO uso8;
#   GRANT ALL ON DATABASE blogdb TO uso8;
resource "google_sql_user" "uso8" {
  name     = "uso8"
  instance = google_sql_database_instance.blog.name
  password = var.db_password
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------
output "cloud_sql_private_ip" {
  value       = google_sql_database_instance.blog.private_ip_address
  description = "Cloud SQL のプライベート IP（アプリ接続先）"
}

output "cloud_sql_connection_name" {
  value       = google_sql_database_instance.blog.connection_name
  description = "Cloud SQL 接続名（Cloud SQL Auth Proxy 用）"
}
