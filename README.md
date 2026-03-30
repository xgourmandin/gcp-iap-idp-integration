# GCP IAP + Identity Platform Integration Demo

Demonstrates how to protect a backend service with **Identity-Aware Proxy (IAP)** using an **external Identity Provider** via **Google Cloud Identity Platform (GCIP / Firebase Auth)**.

```
Browser  →  External HTTPS LB  →  IAP (GCIP)  →  Cloud Run (hello-world)
                                        ↓
                              Custom Sign-in App (Cloud Run)
                               [TypeScript / gcip-iap]
                                        ↓
                              Identity Platform (GCIP)
                               [Google / OIDC / SAML]
```

---

## Architecture

| Component | Description |
|---|---|
| **Cloud Run – hello-world** | `us-docker.pkg.dev/cloudrun/container/hello`, restricted to internal LB ingress |
| **Cloud Run – signin-app** | Custom TypeScript sign-in page; handles the GCIP-IAP auth flow |
| **External Application LB** | Global HTTPS LB (`EXTERNAL_MANAGED`); routes `/prod` and `/prod/*` to the backend |
| **Certificate Manager** | Google-managed cert provisioned via DNS authorisation |
| **Cloud DNS** | DNS challenge (CNAME) + A record for the LB IP |
| **IAP** | Protects the backend service; delegates authentication to Identity Platform |
| **Identity Platform (GCIP)** | External IdP integration (Google Sign-In, OIDC, SAML) |

---

## Prerequisites

1. A GCP project with billing enabled (`project_id` in `terraform.tfvars`).
2. A **Cloud DNS managed zone** that controls your target domain.
3. `gcloud` CLI authenticated: `gcloud auth application-default login`
4. Terraform ≥ 1.14 installed.
5. Docker (to build the `signin-app` image).
6. An Artifact Registry Docker repository (or update `signin_app_image` to any registry).

---

## Quickstart

### 1 · Configure variables

Edit `terraform/terraform.tfvars`:

```hcl
project_id        = "your-project-id"
dns_zone_name     = "your-cloud-dns-zone-name"    # e.g. "my-zone"
domain_name       = "demo.yourdomain.com"          # must belong to the zone above
iap_support_email = "admin@yourdomain.com"
iap_app_title     = "My IAP Demo"
```

### 2 · Enable APIs

```bash
cd terraform
terraform init
terraform apply -target=google_project_service.apis
```

### 3 · Build and push the sign-in app

```bash
# Create an Artifact Registry repo (once)
gcloud artifacts repositories create iap-demo \
  --repository-format=docker \
  --location=europe-west1 \
  --project=p-hes-iapidp-prj-001

# Authenticate Docker
gcloud auth configure-docker europe-west1-docker.pkg.dev

# Build and push
cd ./signin-app
docker build -t europe-west1-docker.pkg.dev/p-hes-iapidp-prj-001/iap-demo/signin-app:latest .
docker push europe-west1-docker.pkg.dev/p-hes-iapidp-prj-001/iap-demo/signin-app:latest
```

Then set in `terraform/terraform.tfvars`:
```hcl
signin_app_image = "europe-west1-docker.pkg.dev/your-project-id/iap-demo/signin-app:latest"
```

### 4 · Create the IAP OAuth 2.0 client (manual — GCP Console)

> **Why manual?** The `google_iap_brand`/`google_iap_client` Terraform resources relied on the
> IAP OAuth Admin API, which was **shut down on March 19, 2026**.

1. **GCP Console → APIs & Services → OAuth consent screen** — configure the consent screen (External or Internal).
2. **GCP Console → APIs & Services → Credentials → Create Credentials → OAuth client ID**
   - Application type: **Web application**
   - Name: `IAP Demo Client`
   - Authorised redirect URI:
     `https://iap.googleapis.com/v1/oauth/clientIds/<CLIENT_ID>:handleRedirect`
     *(update with the generated client ID after creation)*
3. Copy the **Client ID** and **Client secret** into `terraform/terraform.tfvars`:
   ```hcl
   iap_oauth2_client_id     = "1234567890-abc.apps.googleusercontent.com"
   iap_oauth2_client_secret = "GOCSPX-…"
   ```

### 5 · Apply the full Terraform stack

```bash
cd ../terraform
terraform apply
```

This creates (in dependency order):
- Cloud Run services (hello-world + signin-app)
- Global IP address
- Certificate Manager DNS authorisation + challenge CNAME record
- Google-managed TLS certificate + Certificate Map
- External HTTPS load balancer (Serverless NEG → backend → URL map → proxy → forwarding rule)
- IAP backend service configuration (OAuth creds + GCIP/Identity Platform wiring)
- Identity Platform project-level configuration

### 6 · Set Firebase environment variables on the sign-in app

The Identity Platform **Web API key** is in:
`Firebase Console → Project settings → General → Web API Key`

```bash
gcloud run services update iap-signin-app \
  --region=europe-west1 \
  --update-env-vars \
    FIREBASE_API_KEY=AIza...,\
    FIREBASE_PROJECT_ID=your-project-id,\
    FIREBASE_AUTH_DOMAIN=your-project-id.firebaseapp.com
```

### 7 · Configure an external Identity Provider

In **Firebase / Identity Platform Console → Authentication → Sign-in method**, enable at least one
provider (e.g. Google). Alternatively, uncomment the relevant blocks in `terraform/identity_platform.tf`:

```hcl
resource "google_identity_platform_default_supported_idp_config" "google" { … }
resource "google_identity_platform_oauth_idp_config" "oidc"              { … }
resource "google_identity_platform_inbound_saml_config" "saml"           { … }
```

### 8 · Wait for the managed certificate

```bash
gcloud certificate-manager certificates describe iap-demo-cert \
  --project=your-project-id
# Wait until:  state: ACTIVE
```

This can take **15–60 minutes** after the DNS CNAME propagates.

### 9 · Grant users IAP access

```bash
gcloud iap web add-iam-policy-binding \
  --resource-type=backend-services \
  --service=iap-demo-backend \
  --project=your-project-id \
  --member="user:alice@yourdomain.com" \
  --role="roles/iap.httpsResourceAccessor"
```

Then visit `https://demo.yourdomain.com/prod` — you will be redirected to the custom sign-in page.

---

## Repository structure

```
.
├── terraform/
│   ├── backend.tf             GCS remote state
│   ├── main.tf                Provider config + API enablement
│   ├── variables.tf           Input variables
│   ├── terraform.tfvars       Variable values (update before apply)
│   ├── outputs.tf             LB IP, URLs, certificate map ID, DNS challenge record
│   ├── cloudrun.tf            Hello-world + sign-in Cloud Run services
│   ├── dns_cert.tf            Certificate Manager DNS auth + managed cert + A record
│   ├── load_balancer.tf       Global IP, NEG, backend, URL map, proxies, forwarding rules
│   ├── iap.tf                 IAP backend service + GCIP settings (see file for OAuth setup)
│   └── identity_platform.tf   Identity Platform config + provider examples (OIDC/SAML)
└── signin-app/
    ├── src/
    │   ├── server/server.ts   Express server – static files + /api/config endpoint
    │   └── client/app.ts      Browser entry – gcip-iap AuthenticationHandler impl.
    ├── public/index.html      Sign-in page UI (Google Sign-In button)
    ├── build.mjs              esbuild script (bundles client → dist/public/bundle.js)
    ├── tsconfig.server.json   TypeScript config for the Node.js server
    ├── tsconfig.json          Base TypeScript config
    ├── package.json
    └── Dockerfile             Multi-stage build (node:20-alpine)
```

---

## Important notes

| Topic | Note |
|---|---|
| **OAuth client creation** | `google_iap_brand`/`google_iap_client` no longer work (API shutdown Mar 2026). Create the OAuth 2.0 client manually — see step 4 above |
| **Firebase v12 + gcip-iap** | `gcip-iap@0.1.x` declares `firebase@^8` as a peer dep. Firebase v12 ships a full v8-compatible compat layer (`firebase/compat/*`). The `.npmrc` sets `legacy-peer-deps=true` and the three legacy polyfills (`whatwg-fetch`, `url-polyfill`, `promise-polyfill`) are installed as explicit deps |
| **Certificate provisioning** | The LB returns `ERR_SSL_PROTOCOL_ERROR` until the cert reaches `ACTIVE` state (up to 60 min after DNS propagation) |
| **Sign-in app URL** | Terraform wires `google_cloud_run_v2_service.signin.uri` directly into `google_iap_settings` — no manual update needed |
| **GCIP providers** | At least one sign-in provider must be enabled in Identity Platform before the sign-in page works |
| **IAP access policy** | By default no users have `roles/iap.httpsResourceAccessor` — add them explicitly (step 9 above) |
| **Backend protocol** | `google_compute_backend_service.protocol = "HTTPS"` required for Serverless NEG → Cloud Run |
| **`signin_app_image` default** | Until you push a real image, the sign-in service runs the hello-world placeholder — update the variable |
