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

# 起動スクリプト
locals {
  startup_script = <<-EOF
#!/bin/bash
set -e

# ログ出力
exec > >(tee /var/log/startup.log)
exec 2>&1

echo "=== Starting setup at $(date) ==="

# システム更新
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y

# Java 11 のインストール
apt-get install -y openjdk-11-jdk

# PostgreSQL のインストールとセットアップ
apt-get install -y postgresql postgresql-contrib
systemctl start postgresql
systemctl enable postgresql

# データベースとユーザーの作成
sudo -u postgres psql <<PSQL
CREATE DATABASE blogdb;
CREATE USER uso8 WITH PASSWORD 'password';
ALTER USER uso8 CREATEDB;
GRANT ALL PRIVILEGES ON DATABASE blogdb TO uso8;
\q
PSQL

# Git と curl のインストール
apt-get install -y git curl unzip

# アプリケーションのクローン
cd /opt
if [ -d "uso8-blog-03" ]; then
  echo "Repository already exists, pulling latest..."
  cd uso8-blog-03
  git pull
else
  git clone https://github.com/uso6wiz/uso8-blog-03.git
  cd uso8-blog-03
fi

# Gradle Wrapper に実行権限を付与
chmod +x gradlew

# アプリケーションのビルド
echo "Building application..."
./gradlew bootJar --no-daemon -x test

# アプリケーションの起動（バックグラウンドで実行）
echo "Starting application..."
nohup java -jar build/libs/*.jar \
  --spring.profiles.active=production \
  --spring.datasource.url=jdbc:postgresql://localhost:5432/blogdb \
  --spring.datasource.username=uso8 \
  --spring.datasource.password=password \
  > /var/log/blog-app.log 2>&1 &

# 起動確認（最大60秒待機）
echo "Waiting for application to start..."
for i in {1..60}; do
  if curl -f http://localhost:8080 > /dev/null 2>&1; then
    echo "Application started successfully!"
    break
  fi
  sleep 1
done

echo "=== Setup completed at $(date) ==="
EOF
}

# Compute Engine インスタンス
resource "google_compute_instance" "blog_app" {
  name         = "wiz-dev-blog-app"
  machine_type = "e2-standard-2"
  zone         = "${var.region}-a"

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
