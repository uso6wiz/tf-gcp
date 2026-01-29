# -----------------------------------------------------------------------------
# Compute Engine インスタンス（Ubuntu 22.04）
# uso8-blog-03 アプリケーションを起動スクリプトでセットアップ・起動
# -----------------------------------------------------------------------------

data "google_compute_image" "ubuntu" {
  family  = "ubuntu-2204-lts"
  project = "ubuntu-os-cloud"
}

# 外部IPアドレス（静的IP）
resource "google_compute_address" "blog_app" {
  name         = "wiz-dev-blog-app-ip"
  address_type = "EXTERNAL"
  region       = var.region
}

# 起動スクリプト（Cloud SQL プライベート IP 接続）
locals {
  startup_script = <<-EOS
#!/bin/bash
set -e

exec > >(tee /var/log/startup.log)
exec 2>&1

echo "=== Starting setup at $(date) ==="

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y

apt-get install -y openjdk-11-jdk git curl unzip

# アプリケーションのクローン
cd /opt
if [ -d "uso8-blog-03" ]; then
  echo "Repository already exists, pulling latest..."
  cd uso8-blog-03 && git pull
else
  git clone https://github.com/uso6wiz/uso8-blog-03.git && cd uso8-blog-03
fi

chmod +x gradlew
echo "Building application..."
./gradlew bootJar --no-daemon -x test

# Cloud SQL (PostgreSQL) プライベート IP で接続
echo "Starting application (Cloud SQL: ${google_sql_database_instance.blog.private_ip_address})..."
nohup java -jar build/libs/*.jar \
  --spring.profiles.active=production \
  --spring.datasource.url=jdbc:postgresql://${google_sql_database_instance.blog.private_ip_address}:5432/blogdb \
  --spring.datasource.username=uso8 \
  --spring.datasource.password=${var.db_password} \
  > /var/log/blog-app.log 2>&1 &

echo "Waiting for application to start..."
for i in $(seq 1 90); do
  if curl -sf http://localhost:8080 > /dev/null 2>&1; then
    echo "Application started successfully!"
    break
  fi
  sleep 1
done

echo "=== Setup completed at $(date) ==="
EOS
}

# Compute Engine インスタンス（Cloud SQL 作成後に起動）
resource "google_compute_instance" "blog_app" {
  name         = "wiz-dev-blog-app"
  machine_type = "e2-standard-2"
  zone         = "${var.region}-a"

  depends_on = [
    google_sql_database.blogdb,
    google_sql_user.uso8,
  ]

  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu.self_link
      size  = 20
      type  = "pd-standard"
    }
  }

  network_interface {
    network    = google_compute_network.vpc.name
    subnetwork = google_compute_subnetwork.public_1.name

    access_config {
      nat_ip = google_compute_address.blog_app.address
    }
  }

  metadata_startup_script = local.startup_script

  tags = ["http-server", "https-server"]

  service_account {
    email  = google_service_account.compute_engine.email
    scopes = ["cloud-platform"]
  }
}

# Service Account（Compute Engine 用）
resource "google_service_account" "compute_engine" {
  account_id   = "compute-engine-sa"
  display_name = "Compute Engine Service Account"
}

# ファイアウォールルール（HTTP/HTTPS を許可）
resource "google_compute_firewall" "allow_http_https_instance" {
  name    = "wiz-dev-allow-http-https-instance"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server", "https-server"]
}

# Outputs
output "blog_app_external_ip" {
  value       = google_compute_address.blog_app.address
  description = "Blog アプリケーションの外部 IP アドレス（http://<this>:8080 でアクセス可能）"
}

output "blog_app_instance_name" {
  value       = google_compute_instance.blog_app.name
  description = "Blog アプリケーションのインスタンス名"
}

output "blog_app_instance_zone" {
  value       = google_compute_instance.blog_app.zone
  description = "Blog アプリケーションのインスタンスゾーン"
}
