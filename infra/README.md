# OpenBeta Infrastructure (OpenTofu/Terraform)

Infrastructure as Code for OpenBeta PostgreSQL migration project.

## What's Managed

| Resource | Provider | Description |
|----------|----------|-------------|
| Supabase Project | supabase/supabase | Database, Auth, Storage |
| Supabase Settings | supabase/supabase | API config, Auth settings |
| Cloudflare Worker | cloudflare/cloudflare | UI deployment |

## Prerequisites

1. **OpenTofu** (recommended) or Terraform
   ```bash
   # macOS
   brew install opentofu

   # Linux
   curl -fsSL https://get.opentofu.org/install-opentofu.sh | sh
   ```

2. **Supabase Access Token**
   - Go to https://supabase.com/dashboard/account/tokens
   - Create new token with project access

3. **Cloudflare API Token**
   - Go to https://dash.cloudflare.com/profile/api-tokens
   - Create token with permissions:
     - Workers Scripts: Edit
     - Account Settings: Read

## Quick Start

```bash
cd infra

# Copy and edit variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Initialize providers
tofu init

# Preview changes
tofu plan

# Apply changes
tofu apply
```

## Import Existing Resources

If you already have a Supabase project:

```bash
# Import existing Supabase project
tofu import supabase_project.main hswfsehtiwaqcfndygvr
```

## Outputs

After applying, useful values are available:

```bash
# Get Supabase URL
tofu output supabase_api_url

# Get all env vars (for .env file)
tofu output -json env_vars

# Get sensitive values
tofu output -raw supabase_anon_key
```

## CI/CD Integration

For GitHub Actions, set these secrets:
- `TF_VAR_supabase_access_token`
- `TF_VAR_supabase_database_password`
- `TF_VAR_cloudflare_api_token`

Then in your workflow:
```yaml
- uses: opentofu/setup-opentofu@v1
- run: tofu init
- run: tofu apply -auto-approve
```

## File Structure

```
infra/
├── providers.tf          # Provider configuration
├── variables.tf          # Input variables
├── supabase.tf           # Supabase resources
├── cloudflare.tf         # Cloudflare resources
├── outputs.tf            # Output values
├── terraform.tfvars      # Your variables (gitignored)
└── terraform.tfvars.example
```

## Notes

### Supabase Provider
- Provider is in "Public Alpha" but stable for core features
- Project creation takes ~2 minutes
- Settings updates are partial (only specified fields change)

### Cloudflare Worker
- TanStack Start apps are built with `npm run build`
- Deployed with `wrangler deploy` (handles asset upload)
- Terraform manages routes, domains, and secrets

### Hybrid Approach
Some operations work better outside Terraform:
- **Schema migrations**: Use Supabase CLI (`supabase db push`)
- **Worker builds**: Use wrangler (`wrangler deploy`)
- **Secrets**: Can use wrangler or Terraform
