terraform {
  required_version = ">= 1.6.0"

  backend "gcs" {
    bucket = "tfstate-YOUR_PROJECT_ID-asia-n1" # state apply 後に実バケット名に変更
    prefix = "service/dev"
  }

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

data "google_project" "project" {}

output "project_id" {
  value       = data.google_project.project.project_id
  description = "GCP project ID"
}

output "project_number" {
  value       = data.google_project.project.number
  description = "GCP project number"
}
