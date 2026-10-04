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

