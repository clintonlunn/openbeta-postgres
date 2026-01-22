# Output Values

# =============================================================================
# Supabase Outputs
# =============================================================================

output "supabase_project_id" {
  description = "Supabase project reference ID"
  value       = supabase_project.main.id
}

output "supabase_api_url" {
  description = "Supabase API URL"
  value       = "https://${supabase_project.main.id}.supabase.co"
}

output "supabase_anon_key" {
  description = "Supabase anonymous/public API key"
  value       = data.supabase_apikeys.main.anon_key
  sensitive   = true
}

output "supabase_service_role_key" {
  description = "Supabase service role key (admin access)"
  value       = data.supabase_apikeys.main.service_role_key
  sensitive   = true
}

output "supabase_db_host" {
  description = "Supabase database host (direct connection)"
  value       = "db.${supabase_project.main.id}.supabase.co"
}

output "supabase_pooler_host" {
  description = "Supabase connection pooler host"
  value       = "aws-0-${var.supabase_region}.pooler.supabase.com"
}

# =============================================================================
# Cloudflare Outputs (when enabled)
# =============================================================================

# output "cloudflare_worker_url" {
#   description = "Cloudflare Worker URL"
#   value       = "https://${var.cloudflare_worker_name}.workers.dev"
# }

# =============================================================================
# Environment Variables (for .env files or CI/CD)
# =============================================================================

output "env_vars" {
  description = "Environment variables for the application"
  value = {
    VITE_SUPABASE_URL      = "https://${supabase_project.main.id}.supabase.co"
    VITE_SUPABASE_ANON_KEY = data.supabase_apikeys.main.anon_key
  }
  sensitive = true
}
