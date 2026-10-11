module "ack_capability_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "~>6.8"

  name = "ACKCapabilityRole"

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

  inline_policy_permissions = {
    IamManagement = {
      actions = [
        "iam:GetGroup",
        "iam:CreateGroup",
        "iam:DeleteGroup",
        "iam:UpdateGroup",
        "iam:GetRole",
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:UpdateRole",
        "iam:PutRolePermissionsBoundary",
        "iam:PutUserPermissionsBoundary",
        "iam:GetUser",
        "iam:CreateUser",
        "iam:DeleteUser",
        "iam:UpdateUser",
        "iam:GetPolicy",
        "iam:CreatePolicy",
        "iam:DeletePolicy",
        "iam:GetPolicyVersion",
        "iam:CreatePolicyVersion",
        "iam:DeletePolicyVersion",
        "iam:ListPolicyVersions",
        "iam:ListPolicyTags",
        "iam:ListAttachedGroupPolicies",
        "iam:GetGroupPolicy",
        "iam:PutGroupPolicy",
        "iam:AttachGroupPolicy",
        "iam:DetachGroupPolicy",
        "iam:DeleteGroupPolicy",
        "iam:ListAttachedRolePolicies",
        "iam:ListRolePolicies",
        "iam:GetRolePolicy",
        "iam:PutRolePolicy",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:ListAttachedUserPolicies",
        "iam:ListUserPolicies",
        "iam:GetUserPolicy",
        "iam:PutUserPolicy",
        "iam:AttachUserPolicy",
        "iam:DetachUserPolicy",
        "iam:DeleteUserPolicy",
        "iam:ListRoleTags",
        "iam:ListUserTags",
        "iam:TagPolicy",
        "iam:UntagPolicy",
        "iam:TagRole",
        "iam:UntagRole",
        "iam:TagUser",
        "iam:UntagUser",
        "iam:RemoveClientIDFromOpenIDConnectProvider",
        "iam:ListOpenIDConnectProviderTags",
        "iam:UpdateOpenIDConnectProviderThumbprint",
        "iam:UntagOpenIDConnectProvider",
        "iam:AddClientIDToOpenIDConnectProvider",
        "iam:DeleteOpenIDConnectProvider",
        "iam:GetOpenIDConnectProvider",
        "iam:TagOpenIDConnectProvider",
        "iam:CreateOpenIDConnectProvider",
        "iam:UpdateAssumeRolePolicy"
      ]
      resources = ["*"]
    }
  }
}

