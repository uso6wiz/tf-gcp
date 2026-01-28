terraform {
  required_version = ">= 1.6.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  region_short   = "asia-n1" # asia-northeast1 の短縮
  tfstate_bucket = "tfstate-${var.project_id}-${local.region_short}"
  labels = {
    project = "tf-gcp"
    purpose = "terraform-state"
  }
}

# -----------------------------------------------------------------------------
# GCS バケット（Terraform リモート state 用）
# GCS バックエンドはバケット内でロックを管理するため DynamoDB 相当は不要
# -----------------------------------------------------------------------------
resource "google_storage_bucket" "tfstate" {
  name     = local.tfstate_bucket
  location = var.region
  labels   = local.labels

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }
}

resource "google_storage_bucket_iam_member" "tfstate_terraform_sa" {
  bucket = google_storage_bucket.tfstate.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.github_actions_terraform.email}"
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------
output "tfstate_bucket" {
  value       = google_storage_bucket.tfstate.name
  description = "GCS bucket name for Terraform remote state"
}

output "tfstate_prefix" {
  value       = "service/dev"
  description = "State object prefix (key prefix) in the bucket"
}
