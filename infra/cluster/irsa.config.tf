# =================
# IRSA Config for ACK IAM Controller

# Define IAM role for IAM controller
resource "aws_iam_policy" "ack_iam_controller" {
  name = "ACKControllerAllowIAMManagement"
  policy = data.aws_iam_policy_document.ack_iam_controller.json
}

data "aws_iam_policy_document" "ack_iam_controller" {
  statement {
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
# ================
# Define IAM trust policy
data "aws_iam_policy_document" "ack_iam_controller_trust_policy" {
  statement {
    # AWS needs to trust identities minted by k8s OIDC provider
    principals {
      type = "Federated"
      identifiers = [aws_iam_openid_connect_provider.irsa_oidc.arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]
    
    # Where the identities come from
    condition {
      test = "StringEquals"
      variable = "${local._irsa_oidc_issuer}:sub"
      values = ["system:serviceaccount:ack-system:ack-iam-controller"]
    }

    # Which system the identities are meant to be used for
    condition {
      test = "StringEquals"
      variable = "${local._irsa_oidc_issuer}:aud"
      values = [local._irsa_oidc_audience]
    }
  }
}
# =============

resource "aws_iam_role" "ack_iam_controller" {
  name = "ack-iam-controller"
  assume_role_policy = data.aws_iam_policy_document.ack_iam_controller_trust_policy.json
}

resource "aws_iam_role_policy_attachment" "ack_iam_controller" {
  role = aws_iam_role.ack_iam_controller.name
  policy_arn = aws_iam_policy.ack_iam_controller.arn
}