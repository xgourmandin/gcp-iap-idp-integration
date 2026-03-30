# GCP IAP / IDP Integration – Terraform Bootstrap

This repository provisions a GCS bucket on Google Cloud Platform using **Terraform**, authenticated through a **GitHub Actions** pipeline with [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation) (no long-lived service account keys).

---

## Repository Structure

```
.
├── .github/
│   └── workflows/
│       └── terraform.yml        # CI/CD pipeline (plan on PR, apply on merge)
├── terraform/
│   ├── backend.tf               # GCS remote state backend (partial config)
│   ├── main.tf                  # Provider + google_storage_bucket resource
│   ├── variables.tf             # Input variables
│   ├── outputs.tf               # Bucket name / URL outputs
│   └── terraform.tfvars.example # Safe example values (copy → terraform.tfvars locally)
└── README.md
```

---

## Prerequisites

All of the following are **one-time** setup steps that must be completed before the first pipeline run.

### 1. Enable required APIs

```bash
gcloud services enable \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  sts.googleapis.com \
  storage.googleapis.com \
  --project=YOUR_PROJECT_ID
```

### 2. Create a Workload Identity Pool

```bash
gcloud iam workload-identity-pools create "github-pool" \
  --project="YOUR_PROJECT_ID" \
  --location="global" \
  --display-name="GitHub Actions Pool"
```

### 3. Create an OIDC Provider inside the pool

```bash
gcloud iam workload-identity-pools providers create-oidc "github-provider" \
  --project="YOUR_PROJECT_ID" \
  --location="global" \
  --workload-identity-pool="github-pool" \
  --display-name="GitHub Actions Provider" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
  --attribute-condition="assertion.repository_owner == 'YOUR_GITHUB_ORG_OR_USER'"
```

### 4. Create a Service Account for Terraform

```bash
gcloud iam service-accounts create "tf-deployer" \
  --project="YOUR_PROJECT_ID" \
  --display-name="Terraform Deployer"
```

Grant it Storage Admin (adjust to a narrower role if desired):

```bash
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:tf-deployer@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.admin"
```

### 5. Allow the GitHub Actions identity to impersonate the Service Account

```bash
# Get the project number
PROJECT_NUMBER=$(gcloud projects describe YOUR_PROJECT_ID --format='value(projectNumber)')

gcloud iam service-accounts add-iam-policy-binding \
  "tf-deployer@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --project="YOUR_PROJECT_ID" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github-pool/attribute.repository/YOUR_GITHUB_ORG_OR_USER/YOUR_REPO_NAME"
```

### 6. Create the Terraform state bucket (bootstrap – one time only)

```bash
gcloud storage buckets create gs://YOUR_TF_STATE_BUCKET \
  --project=YOUR_PROJECT_ID \
  --location=US \
  --uniform-bucket-level-access

gcloud storage buckets update gs://YOUR_TF_STATE_BUCKET \
  --versioning
```

---

## GitHub Repository Configuration

### Secrets (Settings → Secrets and variables → Actions → Secrets)

| Secret | Value |
|---|---|
| `WIF_PROVIDER` | `projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/providers/github-provider` |
| `WIF_SERVICE_ACCOUNT` | `tf-deployer@YOUR_PROJECT_ID.iam.gserviceaccount.com` |

### Variables (Settings → Secrets and variables → Actions → Variables)

| Variable | Value |
|---|---|
| `GCP_PROJECT_ID` | Your GCP project ID |
| `TF_STATE_BUCKET` | Name of the bootstrap state bucket |
| `GCS_BUCKET_NAME` | Globally unique name for the bucket Terraform will create |

---

## Pipeline Behaviour

| Event | Job | Action |
|---|---|---|
| Pull Request → `main` | `plan` | Runs `terraform plan` and posts the diff as a PR comment |
| Push / Merge → `main` | `apply` | Runs `terraform apply` automatically |

To require **manual approval** before apply, uncomment the `environment: production` line in `.github/workflows/terraform.yml` and configure protection rules on the `production` environment in repository settings.

---

## Running Locally

```bash
cp terraform/terraform.tfvars terraform/terraform.tfvars
# Edit terraform.tfvars with your real values

cd terraform
terraform init -backend-config="bucket=YOUR_TF_STATE_BUCKET"
terraform plan
terraform apply
```

> **Note:** You must have Application Default Credentials configured (`gcloud auth application-default login`) or set `GOOGLE_APPLICATION_CREDENTIALS`.

