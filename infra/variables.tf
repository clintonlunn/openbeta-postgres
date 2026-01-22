# Input Variables for OpenBeta Infrastructure

# =============================================================================
# Supabase Configuration
# =============================================================================

variable "supabase_access_token" {
  description = "Supabase access token from dashboard account settings"
  type        = string
  sensitive   = true
}

variable "supabase_organization_id" {
  description = "Supabase organization slug (from dashboard URL)"
  type        = string
}

variable "supabase_project_name" {
  description = "Name for the Supabase project"
  type        = string
  default     = "openbeta"
}

variable "supabase_region" {
  description = "Supabase region for the project"
  type        = string
  default     = "us-west-2"
}

variable "supabase_database_password" {
  description = "Password for the Supabase database"
  type        = string
  sensitive   = true
}

# =============================================================================
# Cloudflare Configuration (Optional - for custom domains)
# =============================================================================
# Note: Worker deployments use wrangler CLI, not Terraform
# These are only needed if managing custom domains/DNS via Terraform

variable "cloudflare_api_token" {
  description = "Cloudflare API token with Workers permissions"
  type        = string
  sensitive   = true
  default     = ""
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID"
  type        = string
  default     = ""
}

variable "cloudflare_worker_name" {
  description = "Name for the Cloudflare Worker"
  type        = string
  default     = "openbeta-ui"
}

# =============================================================================
# Application Configuration
# =============================================================================

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "auth0_domain" {
  description = "Auth0 domain for JWT validation"
  type        = string
  default     = ""
}

variable "auth0_audience" {
  description = "Auth0 API audience"
  type        = string
  default     = ""
}
