# -----------------------------------------------------------------------------
# GitHub Actions から Terraform apply するための Workload Identity Federation
# google-github-actions/auth で Workload Identity に使用
# -----------------------------------------------------------------------------

data "google_project" "project" {
  project_id = var.project_id
}

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github-pool"
  project                   = var.project_id
  display_name              = "GitHub Actions"
  description               = "OIDC for GitHub Actions (Terraform apply)"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  project                            = var.project_id
  display_name                       = "GitHub OIDC"
  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }
  attribute_condition = var.github_environment != null ? "assertion.repository == '${var.github_org_repo}' && assertion.environment == '${var.github_environment}'" : (
    var.github_branch == "*" ? "assertion.repository == '${var.github_org_repo}'" : "assertion.repository == '${var.github_org_repo}' && assertion.ref == 'refs/heads/${var.github_branch}'"
  )
  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "github_actions_terraform" {
  account_id   = "github-actions-terraform"
  display_name = "GitHub Actions Terraform"
  description  = "Workload Identity for GitHub Actions (Terraform apply)"
  project      = var.project_id
}

# GitHub リポジトリからこの SA を impersonate 可能にする
resource "google_service_account_iam_member" "github_wif" {
  service_account_id = google_service_account.github_actions_terraform.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_org_repo}"
}

# Terraform apply 用: プロジェクト編集権限（VPC, GCE, Cloud SQL 等の操作）
resource "google_project_iam_member" "terraform_apply" {
  project = var.project_id
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.github_actions_terraform.email}"
}

# Service Networking 用: プライベート VPC 接続（Cloud SQL 等）のピアリング作成に必要
# カスタムロールで servicenetworking.services.addPeering 権限を付与
resource "google_project_iam_custom_role" "servicenetworking_peering" {
  role_id     = "servicenetworking_peering"
  title       = "Service Networking Peering"
  description = "Custom role for Service Networking peering creation"
  permissions = [
    "servicenetworking.services.addPeering",
    "compute.networks.updatePolicy",
  ]
}

resource "google_project_iam_member" "servicenetworking" {
  project = var.project_id
  role    = google_project_iam_custom_role.servicenetworking_peering.id
  member  = "serviceAccount:${google_service_account.github_actions_terraform.email}"
}

# -----------------------------------------------------------------------------
# Outputs（GitHub Actions ワークフローで使用）
# -----------------------------------------------------------------------------
output "github_actions_workload_identity_provider" {
  value       = "projects/${data.google_project.project.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github.workload_identity_pool_id}/providers/${google_iam_workload_identity_pool_provider.github.workload_identity_pool_provider_id}"
  description = "Workload Identity Provider (google-github-actions/auth の workload_identity_provider)"
}

output "github_actions_service_account" {
  value       = google_service_account.github_actions_terraform.email
  description = "Service account email for GitHub Actions"
}
