# tf-gcp
Terraform for Google Cloud Platform

## セットアップ

### 前提条件

- `gcloud` CLI がインストールされていること
- Terraform 1.6.0以上がインストールされていること
- GCP プロジェクトが作成済みであること

### GCP認証情報の設定

`gcloud` CLIを使用して認証情報を設定します：

```bash
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

### 実行手順

#### 1. バックエンドの作成（初回のみ）

Terraformの状態管理用のGCSバケットと、GitHub Actions用のWorkload Identityを作成します。

1. `state` ディレクトリに移動します：

```bash
cd state
```

2. Terraformを初期化します：

```bash
terraform init
```

3. 実行計画を確認します：

```bash
terraform plan -var="project_id=YOUR_PROJECT_ID" -var="github_org_repo=myorg/tf-gcp"
```

4. バックエンドリソースを作成します：

```bash
terraform apply -var="project_id=YOUR_PROJECT_ID" -var="github_org_repo=myorg/tf-gcp"
```

確認プロンプトで `yes` を入力して実行します。

これにより、以下のリソースが作成されます：
- GCSバケット（Terraform状態ファイル用、バージョニング有効）
- Workload Identity プール / プロバイダ（GitHub OIDC）
- Service Account（`github-actions-terraform`）

5. 出力値をメモします：

```bash
terraform output tfstate_bucket
terraform output github_actions_workload_identity_provider
terraform output github_actions_service_account
```

#### 2. サービスインフラの作成

バックエンド作成後、`service` ディレクトリでインフラを作成します。

1. `service/main.tf` の `backend "gcs"` の `bucket` を、上記の `tfstate_bucket` 出力値に変更します：

```hcl
backend "gcs" {
  bucket = "tfstate-YOUR_PROJECT_ID-asia-n1"  # state の出力値に変更
  prefix = "service/dev"
}
```

2. `service` ディレクトリに移動します：

```bash
cd ../service
```

3. Terraformを初期化します：

```bash
terraform init
```

4. 実行計画を確認します：

```bash
terraform plan -var="project_id=YOUR_PROJECT_ID"
```

必要に応じて変数を設定できます：

```bash
terraform plan -var="project_id=YOUR_PROJECT_ID" -var="region=asia-northeast1"
```

5. インフラを適用します：

```bash
terraform apply -var="project_id=YOUR_PROJECT_ID"
```

確認プロンプトで `yes` を入力して実行します。

### 変数

主要な変数は `variables.tf` で定義されています。環境変数 `TF_VAR_*` または `-var` オプションで上書きできます。

例：
```bash
export TF_VAR_project_id="your-gcp-project-id"
terraform apply
```

`state/terraform.tfvars.example` および `service/terraform.tfvars.example` をコピーして `terraform.tfvars` を作成し、値を編集して利用することもできます。

### GitHub Actions

1. リポジトリの Secrets に `GCP_PROJECT_ID` を登録します。
2. `state` 適用後、`.github/workflows/terraform-service-apply.yml` の以下を state の出力値に差し替えます：
   - `workload_identity_provider`: `terraform output -raw github_actions_workload_identity_provider` の値
   - `service_account`: `terraform output -raw github_actions_service_account` の値

`service/**` への push（例: `main`）で `terraform apply` が実行されます。

### 注意事項

- GCSバックエンドのバケット名は実際の環境に合わせて変更してください（`service/main.tf` の `backend "gcs"` セクション）
- App Runner 等の AWS 固有サービスに相当するリソースは含めていません。VPC・GCE・Cloud SQL 等は必要に応じて `service/` に追加してください
