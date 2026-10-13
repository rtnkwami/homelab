# NOTE:
# This file configures the OIDC provider for IRSA for an AWS external k8s cluster
# Much of the code was taken from Talos documentation. However, some of the code
# has been altered to make use of current OpenTofu and AWS documentation.
# Unneccessary code has also been dropped in favor of conciseness.
# 
# REF: https://docs.siderolabs.com/talos/v1.13/security/iam-roles-for-service-accounts

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  _irsa_oidc_bucket = "niovial-homelab-oidc"
  _irsa_oidc_issuer = "s3.${data.aws_region.current.region}.amazonaws.com/${local._irsa_oidc_bucket}"
  _irsa_oidc_audience = "sts.amazonaws.com"
  _irsa_tags = {
    Project = "Homelab"
  }
  _irsa_oidc_config_key = ".well-known/openid-configuration"
  _irsa_oidc_jwks_key = "keys.json"
}

# Step 1:
# Generate public/private key pair k8s uses to sign service account tokens
resource "tls_private_key" "service_account_signing_key" {
  algorithm = "RSA"
}

# Step 2:
# Create OIDC configuration and OIDC public signing keys
# ====================
data "external" "pub_der" {
  program = ["bash", "-c", <<EOF
      set -euo pipefail
      pem=$(jq -r .pem)
      der=$(echo "$pem" | openssl pkey -pubin -inform PEM -outform DER | openssl dgst -sha256 -binary | base64 | tr -d '=' | tr '/+' '_-')
      jq -n --arg der "$der" '{"der":$der}'
    EOF
  ]
  query = { pem = tls_private_key.service_account_signing_key.public_key_pem }
}

data "external" "modulus" {
  program = ["bash", "-c", <<EOF
      set -euo pipefail
      pem=$(jq -r .pem)
      modulus=$(echo "$pem" | openssl rsa -inform PEM -modulus -noout | cut -d'=' -f2 | xxd -r -p | base64 | tr -d '=' | tr '/+' '_-')
      jq -n --arg modulus "$modulus" '{"modulus":$modulus}'
    EOF
  ]
  query = { pem = tls_private_key.service_account_signing_key.private_key_pem }
}

locals {
  _irsa_oidc_config = jsonencode({
    issuer = "https://${local._irsa_oidc_issuer}"
    jwks_uri = "https://${local._irsa_oidc_issuer}/${local._irsa_oidc_jwks_key}"
    authorization_endpoint                = "urn:kubernetes:programmatic_authorization"
    response_types_supported              = ["id_token"]
    subject_types_supported               = ["public"]
    id_token_signing_alg_values_supported = ["RS256"]
    claims_supported                      = ["sub", "iss"]
  })

  _irsa_oidc_jwks_ = jsonencode({
    keys = [{
        use = "sig"
        alg = "RS256"
        kty = "RSA"
        kid = data.external.pub_der.result.der
        n   = data.external.modulus.result.modulus
        e   = "AQAB"
    }]
  })
}
# ==================

# Step 3:
# Create S3 bucket to store OIDC documents
resource "aws_s3_bucket" "irsa_oidc" {
  bucket = local._irsa_oidc_bucket
  
  tags = local._irsa_tags
}

# Step 4:
# Upload OIDC documents to IRSA bucket
# ===============
resource "aws_s3_object" "keys_json" {
  bucket = aws_s3_bucket.irsa_oidc.id
  key = local._irsa_oidc_jwks_key
  content = local._irsa_oidc_jwks_
  etag = md5(local._irsa_oidc_jwks_)
  
  tags = local._irsa_tags
}

resource "aws_s3_object" "oidc_config" {
  bucket = aws_s3_bucket.irsa_oidc.id
  key = local._irsa_oidc_config_key
  content = local._irsa_oidc_config
  etag = md5(local._irsa_oidc_config)
  
  tags = local._irsa_tags
}
# =================

# Step 5:
# Make OIDC documents publicly available
resource "aws_s3_bucket_public_access_block" "irsa_oidc" {
  bucket = aws_s3_bucket.irsa_oidc.id

  block_public_acls = true
  ignore_public_acls = true
}

data "aws_iam_policy_document" "allow_irsa_oidc_public_access" {
  statement {
    principals {
      type = "*"
      identifiers = ["*"]
    }

    actions = ["s3:GetObject"]

    resources = [
      "${aws_s3_bucket.irsa_oidc.arn}/${local._irsa_oidc_config_key}",
      "${aws_s3_bucket.irsa_oidc.arn}/${local._irsa_oidc_jwks_key}"
    ]
  }
}

resource "aws_s3_bucket_policy" "allow_irsa_oidc_public_access" {
  bucket = aws_s3_bucket.irsa_oidc.id
  policy = data.aws_iam_policy_document.allow_irsa_oidc_public_access.json
}

# Step 6:
# Configure IRSA bucket as OIDC provider
resource "aws_iam_openid_connect_provider" "irsa_oidc" {
  depends_on = [
    aws_s3_object.oidc_config,
    aws_s3_object.keys_json
  ]

  url = "https://${local._irsa_oidc_issuer}"
  # Which audiences require k8s pods to be registered with the k8s
  # OIDC provider
  client_id_list = [local._irsa_oidc_audience]
}