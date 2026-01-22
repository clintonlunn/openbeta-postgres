# Cloudflare Infrastructure
#
# NOTE: TanStack Start apps are built and deployed using wrangler:
#   cd ui/tanstack && npm run build && wrangler deploy
#
# The Cloudflare Terraform provider v5 changed significantly:
# - Worker secrets are now managed via wrangler CLI (not Terraform)
# - Worker deployments are best handled via wrangler
#
# OpenTofu/Terraform is useful for:
# - Custom domain routes
# - DNS records
# - Account-level settings
# - Page rules, firewall rules, etc.

# =============================================================================
# Custom Domain Route (Optional)
# =============================================================================
# Uncomment and configure when you have a custom domain

# variable "cloudflare_zone_id" {
#   description = "Cloudflare Zone ID for custom domain"
#   type        = string
#   default     = ""
# }

# resource "cloudflare_workers_route" "custom_domain" {
#   zone_id     = var.cloudflare_zone_id
#   pattern     = "app.openbeta.io/*"
#   script_name = var.cloudflare_worker_name
# }

# =============================================================================
# DNS Records (Optional)
# =============================================================================
# If managing DNS in Cloudflare

# resource "cloudflare_record" "app" {
#   zone_id = var.cloudflare_zone_id
#   name    = "app"
#   content = "${var.cloudflare_worker_name}.${var.cloudflare_account_id}.workers.dev"
#   type    = "CNAME"
#   proxied = true
# }
