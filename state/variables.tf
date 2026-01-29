variable "project_id" {
  description = "GCP プロジェクト ID"
  type        = string
  default     = "clgcporg98-p001"
}

variable "region" {
  description = "GCP リージョン（例: asia-northeast1）"
  type        = string
  default     = "asia-northeast1"
}

variable "github_org_repo" {
  description = "GitHub org/repo (例: uso6wiz/tf-gcp). Workload Identity の attribute mapping に使用"
  type        = string
  default     = "uso6wiz/tf-gcp"
}

variable "github_branch" {
  description = "Assume を許可するブランチ（例: main）。'*' で全 ref 許可"
  type        = string
  default     = "main"
}

variable "github_environment" {
  description = "省略可。GitHub environment 名。指定時はその environment に trust を制限"
  type        = string
  default     = null
}
