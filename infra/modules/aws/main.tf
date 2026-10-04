locals {
  vpc_cidr = "10.128.0.0/16"
  
  node_cidrs = {
    public = [
      cidrsubnet(local.vpc_cidr, 4, 0),
      cidrsubnet(local.vpc_cidr, 4, 1),
      cidrsubnet(local.vpc_cidr, 4, 2)
    ]
    private = [
      cidrsubnet(local.vpc_cidr, 4, 3),
      cidrsubnet(local.vpc_cidr, 4, 4),
      cidrsubnet(local.vpc_cidr, 4, 5)
    ]
    database = [
      cidrsubnet(local.vpc_cidr, 4, 6),
      cidrsubnet(local.vpc_cidr, 4, 7),
      cidrsubnet(local.vpc_cidr, 4, 8)
    ]
    intra = [
      cidrsubnet(local.vpc_cidr, 4, 9),
      cidrsubnet(local.vpc_cidr, 4, 10),
      cidrsubnet(local.vpc_cidr, 4, 11)
    ]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~>6.7"

  name = "homelab"
  # NOTE:
  # This is needed if you wish to make eks cluster endpoint private
  enable_dns_hostnames = true
  enable_dns_support = true
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
  
  cidr = local.vpc_cidr
  public_subnets = local.node_cidrs.public
  private_subnets = local.node_cidrs.private
  database_subnets = local.node_cidrs.database
  intra_subnets = local.node_cidrs.intra

  public_subnet_tags = {
    "kubernetes.io/role/elb" = ""
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = ""
  }

  database_subnet_tags = {
    "node.niovial.io/pool" = "database"
  }

  enable_nat_gateway = true
  single_nat_gateway = true
}

module "eks" {
  source = "terraform-aws-modules/eks/aws"
  version = "~>21.26"

  name = "homelab"
  kubernetes_version = "1.36"

  endpoint_public_access = true
  endpoint_private_access = true
  enable_cluster_creator_admin_permissions = true
  create_auto_mode_iam_resources = true
  
  compute_config = {
    enabled = true
    node_pools = ["system"]
  }

  vpc_id = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
}

resource "aws_eks_capability" "ack" {
  cluster_name = module.eks.cluster_name
  capability_name = "ack"
  type = "ACK"
  role_arn = module.ack_capability_role.arn
  delete_propagation_policy = "RETAIN"
}
