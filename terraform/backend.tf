terraform {
  backend "gcs" {
    bucket = "iap-idp-iac-state"
    prefix = "terraform/state"
  }
}


