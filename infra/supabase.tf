# Supabase Infrastructure
# Manages project and settings via Supabase Terraform Provider

# =============================================================================
# Supabase Project
# =============================================================================
# To import existing project:
#   tofu import supabase_project.main <project-ref>
#   e.g., tofu import supabase_project.main hswfsehtiwaqcfndygvr

resource "supabase_project" "main" {
  organization_id   = var.supabase_organization_id
  name              = var.supabase_project_name
  database_password = var.supabase_database_password
  region            = var.supabase_region

  lifecycle {
    # Password is set once and managed outside Terraform
    ignore_changes = [database_password]
  }
}

# =============================================================================
# Project Settings
# =============================================================================

resource "supabase_settings" "main" {
  project_ref = supabase_project.main.id

  # API Settings
  api = jsonencode({
    db_schema            = "public,storage,graphql_public"
    db_extra_search_path = "public,extensions"
    max_rows             = 1000
  })

  # Auth Settings (configure for Auth0 JWT validation if needed)
  # auth = jsonencode({
  #   site_url                 = "https://openbeta.io"
  #   jwt_exp                  = 3600
  #   disable_signup           = false
  #   external_email_enabled   = true
  #   external_phone_enabled   = false
  # })
}

# =============================================================================
# Data Sources
# =============================================================================

data "supabase_apikeys" "main" {
  project_ref = supabase_project.main.id
}
