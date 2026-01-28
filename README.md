# tf-gcp

Terraform for Google Cloud Platform（tf-aws の GCP 版）

## セットアップ

### 前提条件

- `gcloud` CLI がインストール済みであること
- Terraform 1.6.0 以上
- GCP プロジェクトが作成済みであること

### GCP 認証

```bash
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

### 実行手順

#### 1. バックエンドの作成（初回のみ）

Terraform の state 用 GCS バケットと、GitHub Actions 用 Workload Identity を作成します。

1. `state` ディレクトリに移動:

```bash
cd state
```

2. 変数を指定して初期化・適用:

```bash
terraform init
terraform plan -var="project_id=YOUR_PROJECT_ID" -var="github_org_repo=myorg/tf-gcp"
terraform apply -var="project_id=YOUR_PROJECT_ID" -var="github_org_repo=myorg/tf-gcp"
```

作成されるリソース:

- GCS バケット（state 用、バージョニング有効）
- Workload Identity プール / プロバイダ（GitHub OIDC）
- Service Account（`github-actions-terraform`）

3. 出力をメモ:

- `tfstate_bucket`: service の backend で使用するバケット名
- `github_actions_workload_identity_provider`: GitHub Actions の `workload_identity_provider`
- `github_actions_service_account`: GitHub Actions の `service_account`

#### 2. サービス用 Terraform の作成

1. `service/main.tf` の `backend "gcs"` の `bucket` を、`state` の `tfstate_bucket` 出力値に合わせて変更:

```hcl
backend "gcs" {
  bucket = "tfstate-YOUR_PROJECT_ID-asia-n1"  # 上記の tfstate_bucket に変更
  prefix = "service/dev"
}
```

2. `service` で初期化・適用:

```bash
cd ../service
terraform init
terraform plan -var="project_id=YOUR_PROJECT_ID"
terraform apply -var="project_id=YOUR_PROJECT_ID"
```

### 変数

| 変数 | 説明 | デフォルト |
|------|------|------------|
| `project_id` | GCP プロジェクト ID | （必須） |
| `region` | リージョン | `asia-northeast1` |
| `github_org_repo` | GitHub org/repo（state のみ） | （必須） |
| `github_branch` | 許可するブランチ | `main` |
| `github_environment` | GitHub environment で制限する場合 | `null` |

`state/terraform.tfvars.example` および `service/terraform.tfvars.example` をコピーして `terraform.tfvars` を作成し、値を編集して利用できます。

### GitHub Actions

1. リポジトリの Secrets に `GCP_PROJECT_ID` を登録する。
2. `state` 適用後、`.github/workflows/terraform-service-apply.yml` の以下を **state の出力値** に差し替える:
   - `workload_identity_provider`: `terraform output -raw github_actions_workload_identity_provider`
   - `service_account`: `terraform output -raw github_actions_service_account`
3. `project_id`（auth 用）は `secrets.GCP_PROJECT_ID` を参照しているので、Secret の設定のみでよい。

`service/**` への push（例: `main`）で `terraform apply` が実行されます。

### 注意事項

- state 用バケット名は `tfstate-{project_id}-asia-n1` です。`service` の backend は必ず一致させてください。
- App Runner 等の AWS 固有サービスに相当するリソースは含めていません。VPC・GCE・Cloud SQL 等は必要に応じて `service/` に追加してください。
- `terraform init` 実行時に `state/` および `service/` に `.terraform.lock.hcl` が生成されます。再現性のためコミットすることを推奨します。
