# EKS + app state — PostgreSQL backend (e.g. AWS RDS). Decrypt first: bin/decrypt-secrets.
# For RDS, .backend should include conn_str with sslmode=require (e.g. postgres://user:pass@host:5432/db?sslmode=require).
#
# Init (from ops/provision/):
#   terraform init -backend-config=.backend
# Optional: separate schema so state doesn't mix with other configs in the same DB:
#   terraform init -backend-config=.backend -backend-config=schema_name=eks_r2_bl_ethos
terraform {
  backend "pg" {}
}
