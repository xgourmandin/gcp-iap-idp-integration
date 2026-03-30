# Configuring Identity Platform with Auth0 (OIDC)

This guide walks through connecting **Auth0** as an external identity provider to
**Google Cloud Identity Platform (GCIP)** so that IAP-protected resources use Auth0
for authentication.

---

## Prerequisites

| Requirement | Details |
|---|---|
| Auth0 account | Free or paid – [auth0.com](https://auth0.com) |
| GCP project | Deployed with this Terraform stack; Identity Platform API enabled |
| `terraform apply` completed (baseline) | At minimum `google_identity_platform_config.main` must exist |

---

## Overview

```
Browser → IAP → signin-app (gcip-iap) → Identity Platform (GCIP)
                                                  ↓
                                          OIDC Federation
                                                  ↓
                                              Auth0
```

Identity Platform acts as the OIDC *Relying Party*. Auth0 is the *Authorization Server*.
GCIP handles token validation and converts Auth0's `id_token` into a Firebase ID token
that IAP then trusts.

---

## Step 1 – Create an Auth0 Application

1. Log in to your **Auth0 Dashboard** → **Applications → Applications → Create Application**.
2. Choose **Regular Web Application** and give it a name (e.g. `GCP IAP Demo`).
3. On the **Settings** tab, note the following values — you will need them later:

   | Auth0 value | Used as |
   |---|---|
   | **Domain** (e.g. `dev-abc123.us.auth0.com`) | OIDC `issuer` URL |
   | **Client ID** | OIDC `client_id` |
   | **Client Secret** | OIDC `client_secret` |

4. Under **Application URIs → Allowed Callback URLs**, add:

   ```
   https://<YOUR_PROJECT_ID>.firebaseapp.com/__/auth/handler
   ```

   Replace `<YOUR_PROJECT_ID>` with your GCP project ID (e.g. `p-hes-iapidp-prj-001`).

5. Click **Save Changes**.

> **Tip:** If you use a custom `authDomain` (e.g. `auth.yourdomain.com`), add that
> callback URL instead and update the `FIREBASE_AUTH_DOMAIN` env-var on the sign-in
> Cloud Run service accordingly.

---

## Step 2 – Add the OIDC Provider via Terraform

### 2a – Add variables

Add the following to `terraform/variables.tf`:

```hcl
# ─────────────────────────────────────────────
# Auth0 OIDC provider
# ─────────────────────────────────────────────
variable "auth0_domain" {
  description = "Auth0 tenant domain, e.g. dev-abc123.us.auth0.com"
  type        = string
  default     = ""
}

variable "auth0_client_id" {
  description = "Auth0 application Client ID."
  type        = string
  default     = ""
  sensitive   = true
}

variable "auth0_client_secret" {
  description = "Auth0 application Client Secret."
  type        = string
  default     = ""
  sensitive   = true
}
```

### 2b – Set values

Add the following to `terraform/terraform.tfvars`:

```hcl
# Auth0 OIDC provider
auth0_domain        = "dev-abc123.us.auth0.com"
auth0_client_id     = "REPLACE_WITH_AUTH0_CLIENT_ID"
auth0_client_secret = "REPLACE_WITH_AUTH0_CLIENT_SECRET"
```

### 2c – Uncomment / add the OIDC resource

In `terraform/identity_platform.tf`, **replace** the commented-out generic OIDC example
with the following Auth0-specific block:

```hcl
resource "google_identity_platform_oauth_idp_config" "auth0" {
  project       = var.project_id
  name          = "oidc.auth0"           # must start with "oidc."
  display_name  = "Auth0"
  issuer        = "https://${var.auth0_domain}/"
  client_id     = var.auth0_client_id
  client_secret = var.auth0_client_secret
  enabled       = true

  depends_on = [google_identity_platform_config.main]
}
```

> **Name constraint:** Identity Platform requires OIDC provider names to start with
> `oidc.`. The value `oidc.auth0` will be used as the `providerId` in the client SDK.

### 2d – Apply

```bash
cd terraform
terraform apply -target=google_identity_platform_oauth_idp_config.auth0
```

---

## Step 3 – Wire Auth0 into the Sign-in App

The `signin-app` client (`src/client/app.ts`) uses `gcip-iap` to start the sign-in
flow. When your Identity Platform project has multiple providers you must tell the
handler which one to invoke. Update the `startSignIn` method to trigger the Auth0 OIDC
flow:

> **Note:** `gcip-iap@2.0.0` requires `firebase@^9.8.3` as a peer dependency.
> The project pins Firebase to this range — do **not** upgrade to v10+ or
> `npm ci` will fail with an `ERESOLVE` conflict.

```typescript
// src/client/app.ts  — inside IAPAuthHandler
// Uses firebase/compat/* (Firebase v9 compat layer) as required by gcip-iap v2.

async startSignIn(auth: firebase.auth.Auth, tenantInfo?: SelectedTenantInfo): Promise<void> {
  show("sign-in-container");

  // Auth0 OIDC provider — name must match the resource created in Terraform
  const provider = new firebase.auth.OAuthProvider("oidc.auth0");

  // Optional: request additional scopes from Auth0
  provider.addScope("openid");
  provider.addScope("profile");
  provider.addScope("email");

  // Optional: pass Auth0-specific parameters
  // provider.setCustomParameters({ prompt: "login" });

  try {
    await auth.signInWithPopup(provider);
    // gcip-iap automatically handles the IAP token exchange after this resolves
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    text("error-message", message);
    show("error-container");
    hide("sign-in-container");
  }
}
```

If you prefer a **redirect flow** (recommended for mobile / Safari), replace
`signInWithPopup` with `signInWithRedirect`:

```typescript
await auth.signInWithRedirect(provider);
```

---

## Step 4 – Update the Sign-in Page UI (optional)

Add an Auth0 sign-in button in `signin-app/public/index.html`:

```html
<!-- inside the #sign-in-container div -->
<button id="auth0-btn" class="btn" onclick="triggerAuth0()">
  Sign in with Auth0
</button>
```

And trigger it from `app.ts` (or a separate `<script>` block) by calling
`startSignIn` with the appropriate auth instance.

---

## Step 5 – Rebuild and Redeploy the Sign-in App

After modifying `app.ts`:

```bash
cd signin-app
docker build -t europe-west1-docker.pkg.dev/p-hes-iapidp-prj-001/iap-demo/signin-app:latest .
docker push europe-west1-docker.pkg.dev/p-hes-iapidp-prj-001/iap-demo/signin-app:latest

# Force Cloud Run to pick up the new image
gcloud run services update iap-signin-app \
  --region=europe-west1 \
  --project=p-hes-iapidp-prj-001 \
  --image=europe-west1-docker.pkg.dev/p-hes-iapidp-prj-001/iap-demo/signin-app:latest
```

---

## Step 6 – Verify the Flow

1. Navigate to `https://<domain_name>/prod`.
2. IAP redirects to the custom sign-in app.
3. Clicking the Auth0 button opens the Auth0 Universal Login page (popup or redirect).
4. After successful Auth0 authentication, Identity Platform validates the OIDC token and
   issues a Firebase ID token.
5. `gcip-iap` exchanges the Firebase ID token for an IAP token and redirects back to
   `/prod`.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `npm error ERESOLVE` / `peer firebase@"^9.8.3"` | `firebase` upgraded above v9 | Pin `"firebase": "^9.8.3"` in `package.json` and run `npm install` |
| `auth/invalid-oauth-client-id` | Mismatched `client_id` | Re-check `auth0_client_id` in `terraform.tfvars` |
| `auth/unauthorized-domain` | Callback URL not in Auth0 allow-list | Add `https://<project>.firebaseapp.com/__/auth/handler` to **Allowed Callback URLs** in Auth0 |
| `auth/invalid-credential` | Wrong `issuer` URL | Must be `https://<auth0_domain>/` (trailing slash required) |
| `provider not found` | Terraform not applied / wrong name | Run `terraform apply`; confirm provider ID starts with `oidc.` |
| Auth0 shows `connection refused` | GCIP project ID wrong | Verify `FIREBASE_PROJECT_ID` env-var on the Cloud Run service |

> **Known audit warning:** `npm audit` reports 4 moderate vulnerabilities in
> `@grpc/grpc-js` (via `@firebase/firestore`). The suggested fix is to upgrade
> Firebase to v12, which would break `gcip-iap@2.0.0`'s peer dependency. Since this
> app only uses **Firebase Auth** (never Firestore), the Firestore/gRPC code path is
> never exercised and the warning can be safely ignored.

### Inspect the OIDC provider configuration

```bash
# List all OIDC providers registered with Identity Platform
gcloud identity platform tenants default-supported-idps list \
  --project=p-hes-iapidp-prj-001

# Or, using the REST API:
curl -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  "https://identitytoolkit.googleapis.com/v2/projects/p-hes-iapidp-prj-001/oauthIdpConfigs"
```

---

## Security Considerations

- Store `auth0_client_secret` in a secret manager (e.g. **GCP Secret Manager** or
  **HashiCorp Vault**) rather than plain-text in `terraform.tfvars`. Use a
  `data "google_secret_manager_secret_version"` data source to inject it at plan time.
- Enable **Auth0 Brute-force Protection** and **Suspicious IP Throttling** in
  Auth0 Dashboard → Security → Attack Protection.
- Consider restricting Auth0 connections to only the required social/enterprise
  connections (e.g. disable Database connections if SSO-only is desired).
- Review Auth0 **Logs** (`Auth0 Dashboard → Monitoring → Logs`) after first sign-in
  to confirm the flow is clean and no `failed_login` events appear.

