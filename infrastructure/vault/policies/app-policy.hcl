path "secret/data/*" {
  capabilities = ["read", "list"]
}

path "secret/data/dev/*" {
  capabilities = ["read", "list"]
}

path "secret/data/uat/*" {
  capabilities = ["read", "list"]
}

path "secret/data/prd/*" {
  capabilities = ["read", "list"]
}
