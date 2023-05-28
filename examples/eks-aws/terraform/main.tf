# terraform/main.tf

locals {
  cluster_name = "my-cluster"
}

data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.66.0"

  name = local.cluster_name
  cidr = "10.0.0.0/16"

  azs = data.aws_availability_zones.available.names

  private_subnets = [
    "10.0.1.0/24",
    "10.0.2.0/24",
    "10.0.3.0/24",
  ]

  public_subnets = [
    "10.0.11.0/24",
    "10.0.12.0/24",
    "10.0.13.0/24",
  ]

  # NAT Gateway Scenarios : One NAT Gateway per availability zone
  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  private_subnet_tags = {
    "kubernetes.io/cluster/default"   = "shared"
    "kubernetes.io/role/internal-elb" = "1"
  }

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
}

module "cluster" {
  source = "git::https://github.com/camptocamp/devops-stack.git//modules/eks/aws?ref=v0.47.0"

  cluster_name = local.cluster_name
  vpc_id       = module.vpc.vpc_id

  worker_groups = [
    {
      instance_type        = "t2.micro"
      asg_desired_capacity = 2
      asg_max_size         = 3
    }
  ]

  base_domain     = "cloudstatus.ml"

  cognito_user_pool_id     = aws_cognito_user_pool.pool.id
  cognito_user_pool_domain = aws_cognito_user_pool_domain.pool_domain.domain
}

resource "aws_cognito_user_pool" "pool" {
  name = "pool"
}

resource "aws_cognito_user_pool_domain" "pool_domain" {
  domain       = "pool-domain"
  user_pool_id = aws_cognito_user_pool.pool.id
}
