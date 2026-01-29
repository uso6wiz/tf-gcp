variable "project_id" {
  description = "GCP プロジェクト ID"
  type        = string
}

variable "region" {
  description = "GCP リージョン（例: asia-northeast1）"
  type        = string
  default     = "asia-northeast1"
}

variable "db_password" {
  description = "Cloud SQL (PostgreSQL) ユーザー uso8 のパスワード"
  type        = string
  sensitive   = true
  default     = "password"
}
