# ─────────────────────────────────────────────────────────────────
# Identity Platform (GCIP)
#
# Enabling Identity Platform allows IAP to delegate authentication
# to external identity providers (Google, OIDC, SAML, etc.).
#
# After apply, configure providers in the Firebase / Identity Platform
# console, or via google_identity_platform_oauth_idp_config /
# google_identity_platform_inbound_saml_config resources below.
# ─────────────────────────────────────────────────────────────────
resource "google_identity_platform_config" "main" {
  project                    = var.project_id
  autodelete_anonymous_users = true

  # Domains that Firebase Auth is permitted to redirect to / run on.
  # The two *.firebaseapp.com / *.web.app entries are GCP defaults; the
  # custom domain and the Cloud Run URL must be added explicitly or the
  # browser receives "Unauthorized domain" when the sign-in page loads.
  authorized_domains = [
    "${var.project_id}.firebaseapp.com",
    "${var.project_id}.web.app",
    var.domain_name,
    trimprefix(google_cloud_run_v2_service.signin.uri, "https://"),
    # Required so Firebase Auth allows the IAP token-exchange redirect:
    # https://iap.googleapis.com/v1beta1/gcip/resources/<id>:handleRedirect
    "iap.googleapis.com",
  ]

  multi_tenant {
    allow_tenants = false
  }

  depends_on = [google_project_service.apis]
}

# ─────────────────────────────────────────────────────────────────
# Example: Google OAuth provider (external IdP)
#
# Uncomment and fill in your OAuth 2.0 client credentials.
# Create an OAuth client at https://console.cloud.google.com/apis/credentials
# ─────────────────────────────────────────────────────────────────
# resource "google_identity_platform_default_supported_idp_config" "google" {
#   project     = var.project_id
#   idp_id      = "google.com"
#   client_id   = "<YOUR_GOOGLE_OAUTH_CLIENT_ID>"
#   client_secret = "<YOUR_GOOGLE_OAUTH_CLIENT_SECRET>"
#   enabled     = true
#   depends_on  = [google_identity_platform_config.main]
# }

# ─────────────────────────────────────────────────────────────────
# Example: Custom OIDC provider
# ─────────────────────────────────────────────────────────────────
# resource "google_identity_platform_oauth_idp_config" "oidc" {
#   project       = var.project_id
#   name          = "oidc.my-provider"
#   display_name  = "My OIDC Provider"
#   issuer        = "https://accounts.my-idp.com"
#   client_id     = "<OIDC_CLIENT_ID>"
#   client_secret = "<OIDC_CLIENT_SECRET>"
#   enabled       = true
#   depends_on    = [google_identity_platform_config.main]
# }

data "google_secret_manager_secret_version" "auth0_client_secret" {
  secret = "auth0-client-secret"
}

resource "google_identity_platform_oauth_idp_config" "auth0" {
  project       = var.project_id
  name          = "oidc.auth0" # must start with "oidc."
  display_name  = "Auth0"
  issuer        = "https://dev-llqbjh7vkrup7yi7.us.auth0.com/"
  client_id     = "dCIQJY1rukrvwo3rUfoZGhPImVu0RjyR"
  client_secret = data.google_secret_manager_secret_version.auth0_client_secret.secret_data
  enabled       = true

  response_type {
    code     = true
    id_token = false
  }

  depends_on = [google_identity_platform_config.main]
}

# ─────────────────────────────────────────────────────────────────
# Example: SAML provider
# ─────────────────────────────────────────────────────────────────
# resource "google_identity_platform_inbound_saml_config" "saml" {
#   project      = var.project_id
#   name         = "saml.my-provider"
#   display_name = "My SAML Provider"
#   enabled      = true
#   idp_config {
#     idp_entity_id = "https://my-saml-idp.com"
#     sign_request  = true
#     idp_certificates {
#       x509_certificate = file("${path.module}/saml-cert.pem")
#     }
#     sso_url = "https://my-saml-idp.com/sso"
#   }
#   sp_config {
#     sp_entity_id = "projects/${var.project_id}/..."
#     callback_uri = "https://...firebaseapp.com/__/auth/handler"
#   }
#   depends_on = [google_identity_platform_config.main]
# }

