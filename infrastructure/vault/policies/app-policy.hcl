# ==============================================================================
# Vault Application Policy (Least Privilege Read-Only)
# Allows microservices & ExternalSecrets to read secret data & list metadata
# ==============================================================================

path "secret/data/*" {
  capabilities = ["read"]
}

path "secret/data/dev/*" {
  capabilities = ["read"]
}

path "secret/data/uat/*" {
  capabilities = ["read"]
}

path "secret/data/prd/*" {
  capabilities = ["read"]
}

# Metadata listing capability for Vault UI & Vault Agent
path "secret/metadata/*" {
  capabilities = ["list", "read"]
}
