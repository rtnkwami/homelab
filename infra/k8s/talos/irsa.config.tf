# NOTE:
# Generic role for all controllers in cluster to authN to AWS
# and assume specific roles for specific tasks. The below configuration
# requires the IAMRoleSelector configuration to be set on all deployed ACK controllers
module "aws_controllers_k8s_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "~>6.8"

  name = "AwsControllersK8sRole"
  use_name_prefix = false

  trust_policy_permissions = {
    TrustTalosK8sOIDC = {
      principals = [{
        type = "Federated"
        identifiers = [aws_iam_openid_connect_provider.irsa_oidc.arn]
      }]
      actions = ["sts:AssumeRoleWithWebIdentity"]
    }
  }

  trust_policy_conditions = [
    {
      test = "StringEquals"
      variable = "${local._irsa_oidc_issuer}:aud"
      values = [local._irsa_oidc_audience]
    },
    {
      test = "StringLike"
      variable = "${local._irsa_oidc_issuer}:sub"
      values = ["system:serviceaccount:ack-system:*"]
    }
  ]
}

# NOTE:
# Permission that allows generic ACK role to assume granular roles for specific tasks
resource "aws_iam_role_policy" "assume_granular_ack_roles" {
  role = module.aws_controllers_k8s_role.name
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
      Resource = [module.iam_role_creator_role.arn]
    }]
  })
}

# NOTE:
# Granular roles for access to AWS services that ACK controllers can assume
module "iam_role_creator_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "~>6.8"

  name = "IAMRoleCreator"
  use_name_prefix = false

  trust_policy_permissions = {
    TrustAckControllers = {
      principals = [{
        type = "AWS"
        identifiers = [module.aws_controllers_k8s_role.arn]
      }]
      actions = ["sts:AssumeRole", "sts:TagSession"]
    }
  }
  
  create_inline_policy = true
  
  inline_policy_permissions = {
    IAMRoleCreationPermissionPolicy = {
      actions = [
        "iam:GetRole",
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:UpdateRole",
        "iam:PutRolePermissionsBoundary",
        "iam:GetPolicy",
        "iam:CreatePolicy",
        "iam:DeletePolicy",
        "iam:GetPolicyVersion",
        "iam:CreatePolicyVersion",
        "iam:DeletePolicyVersion",
        "iam:ListPolicyVersions",
        "iam:ListPolicyTags",
        "iam:ListAttachedRolePolicies",
        "iam:ListRolePolicies",
        "iam:GetRolePolicy",
        "iam:PutRolePolicy",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:ListRoleTags",
        "iam:TagPolicy",
        "iam:UntagPolicy",
        "iam:TagRole",
        "iam:UntagRole",
        "iam:UpdateAssumeRolePolicy",
        "iam:PassRole"
      ]
      resources = ["*"]
    }
  }
}
