# OpenTofu/Terraform Provider Configuration
# Compatible with both OpenTofu and Terraform

terraform {
  required_version = ">= 1.0"

  required_providers {
    supabase = {
      source  = "supabase/supabase"
      version = "~> 1.0"
    }
    # Cloudflare provider available for custom domains/DNS management
    # Uncomment if needed
    # cloudflare = {
    #   source  = "cloudflare/cloudflare"
    #   version = "~> 5.11"
    # }
  }
}

# Supabase Provider
# Get access token from: https://supabase.com/dashboard/account/tokens
provider "supabase" {
  access_token = var.supabase_access_token
}

# Cloudflare Provider (optional - for custom domains)
# Get API token from: https://dash.cloudflare.com/profile/api-tokens
# provider "cloudflare" {
#   api_token = var.cloudflare_api_token
# }
