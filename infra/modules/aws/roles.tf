module "ack_capability_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "~>6.8"

  name = "ACKCapabilityRole"
  use_name_prefix = false

  trust_policy_permissions = {
    TrustEksCapabilities = {
      principals = [
        {
          type = "Service"
          identifiers = ["capabilities.eks.amazonaws.com"]
        }
      ]
      actions = ["sts:AssumeRole", "sts:TagSession"]
    }
  }
}

resource "aws_iam_role_policy" "assume_ack_iam_role" {
  role = module.ack_capability_role.name
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Resource = module.iam_controller_role.arn
      }
    ]
  })
}

# TODO: Add permissions boundary to iam_controller_role permissions
# to prevent the roles it creates from privilege escalation
module "iam_controller_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "~>6.8"

  name = "ack-iam-controller"
  use_name_prefix = false

  trust_policy_permissions = {
    TrustEksCapabilityRole = {
      principals = [
        {
          type = "AWS"
          identifiers = [module.ack_capability_role.arn]
        }
      ]
      actions = ["sts:AssumeRole", "sts:TagSession"]
    }
  }

  create_inline_policy = true

  inline_policy_permissions = {
    IamManagement = {
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

    EksAssociationManagement = {
      actions = [
        "eks:CreatePodIdentityAssociation",
        "eks:DescribePodIdentityAssociation",
        "eks:DeletePodIdentityAssociation",
        "eks:TagResource"
      ]
      resources = ["*"]
    }
  }
}

