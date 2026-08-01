module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.cluster_name
  kubernetes_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  endpoint_public_access  = true
  endpoint_private_access = true

  # THE ACTUAL FIX: without this, nodes launch with no CNI plugin
  # installed, get stuck NetworkPluginNotReady forever, and the node
  # group times out as CREATE_FAILED — exactly what we've been seeing.
  addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni = {
      before_compute = true # install CNI before nodes come online
    }
    eks-pod-identity-agent = {
      before_compute = true
    }
  }

  enabled_log_types                      = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  cloudwatch_log_group_retention_in_days = 1

  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    terraweek_nodes = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = [var.node_instance_type]
      min_size       = 1
      max_size       = 3
      desired_size   = var.node_desired_count
    }
  }

  tags = {
    Environment = "dev"
    Project     = "TerraWeek"
    ManagedBy   = "Terraform"
  }
}
