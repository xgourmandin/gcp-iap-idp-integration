project_id        = "p-hes-iapidp-prj-001"
project_number    = "150073701989"
region            = "europe-west1"
environment       = "prod"

# Replace with your Cloud DNS managed zone name and a domain it controls
dns_zone_name     = "hes-demo-zone"
domain_name       = "prod.iapidp.gcp.hestia09.fr"

# Email shown on the IAP OAuth consent screen
iap_support_email = "admin@example.com"
iap_app_title     = "HES IAP-IDP Demo"

# OAuth 2.0 credentials for IAP (create manually — see terraform/iap.tf for instructions)
iap_oauth2_client_id     = "150073701989-o11nqj65vscfac7h4v0vb9shocga0nmc.apps.googleusercontent.com"

# After building and pushing signin-app/ image, set this to the Artifact Registry path
signin_app_image = "europe-west1-docker.pkg.dev/p-hes-iapidp-prj-001/iap-demo/signin-app:latest"


