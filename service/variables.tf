variable "project_id" {
  description = "GCP プロジェクト ID"
  type        = string
}

variable "region" {
  description = "GCP リージョン（例: asia-northeast1）"
  type        = string
  default     = "asia-northeast1"
}
