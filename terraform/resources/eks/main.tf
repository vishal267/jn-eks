module "eks" {
  source  = "registry.terraform.io/terraform-aws-modules/eks/aws"
  version = "19.10.0"

  cluster_name                    = var.cluster_name
  cluster_version                 = var.cluster_version
  vpc_id                          = data.terraform_remote_state.network.outputs.vpc_id
  subnet_ids                      = [data.terraform_remote_state.network.outputs.private_subnets][0]
  enable_irsa                     = true
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true




  cluster_addons = {
    coredns = {
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {}
    vpc-cni = {
      resolve_conflicts = "OVERWRITE"
    }
    aws-ebs-csi-driver = {
      resolve_conflicts = "OVERWRITE"
    }
  }

  cluster_security_group_additional_rules = {
    egress_nodes_ephemeral_ports_tcp = {
      description                = "Egress Allowed 1025-65535"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "egress"
      source_node_security_group = true
    }
    ingress_nodes_karpenter_ports_tcp = {
      description                = "Karpenter required port"
      protocol                   = "tcp"
      from_port                  = 8443
      to_port                    = 8443
      type                       = "ingress"
      source_node_security_group = true
    }
  }

  node_security_group_additional_rules = {

    ingress_self_all = {
      description = "Self allow all ingress"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }



    egress_all = {
      description      = "Egress allow all"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }



  }

  cluster_timeouts = {
    create = "60m"
    delete = "30m"
  }

  create_iam_role = true
  iam_role_name   = "eks-cluster-role"


  cluster_enabled_log_types = []

  create_cluster_security_group       = true
  create_node_security_group          = true
  node_security_group_use_name_prefix = false
  node_security_group_tags = {
    "karpenter.sh/discovery/${var.cluster_name}" = var.cluster_name
  }



  eks_managed_node_groups = {

    on-demand = {
      min_size     = 2
      max_size     = 2
      desired_size = 2
      update_config = {
        max_unavailable = 1
      }

      iam_role_additional_policies = {
        AmazonEKSVPCResourceController = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController",
        AmazonSSMManagedInstanceCore   = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
        AmazonEBSCSIDriverPolicy       = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }


      create_launch_template     = true
      instance_types             = ["t3a.small"]
      capacity_type              = "ON_DEMAND"
      subnet_ids                 = [data.terraform_remote_state.network.outputs.private_subnets][0]
      use_custom_launch_template = true
      enable_monitoring          = true
      ebs_optimized              = true

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 50
            volume_type           = "gp3"
            iops                  = 3000
            throughput            = 150
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      tags = {
        Environment             = "dev"
        Terraform               = "true"
      }
      labels = {
        Environment                  = "dev"
        lifecycle                    = "Ec2OnDemand"
        "karpenter.sh/capacity-type" = "on-demand"
      }
    }



    spot = {
      min_size     = 0
      max_size     = 1
      desired_size = 0

      iam_role_additional_policies = {
        AmazonEKSVPCResourceController = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController",
        AmazonSSMManagedInstanceCore   = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
        AmazonEBSCSIDriverPolicy       = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }


      create_launch_template     = true
      instance_types             = ["t3a.medium"]
      capacity_type              = "SPOT"
      subnet_ids                 = [data.terraform_remote_state.network.outputs.private_subnets][0]
      use_custom_launch_template = true
      disk_type                  = "gp3"
      disk_encrypted             = true
      disk_size                  = 50
      update_config = {
        max_unavailable = 1
      }
      enable_monitoring = true
      ebs_optimized     = true
      labels = {
        Environment                  = "dev"
        lifecycle                    = "Ec2Spot"
        "aws.amazon.com/spot"        = "true"
        "karpenter.sh/capacity-type" = "spot"
      }



      tags = {
        Environment             = "dev"
        Terraform               = "true"
      }
    }


  }

  tags = {
    "karpenter.sh/discovery/${var.cluster_name}" = var.cluster_name
  }


 # manage_aws_auth_configmap = false
   create_aws_auth_configmap = true
   manage_aws_auth_configmap = true
  
  aws_auth_roles = [
    {
      rolearn  = module.eks_admins_iam_role.iam_role_arn
      username = module.eks_admins_iam_role.iam_role_name
      groups   = ["system:masters"]
    },
   ]
  aws_auth_users = [
    {
      userarn  = "arn:aws:iam::647712509431:user/vishalarora"
      username = "vishal"
      groups   = ["system:masters"]
    },
  ]

}

data "aws_eks_cluster" "default" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "default" {
  name = module.eks.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.default.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.default.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.default.token
}

provider "kubernetes" {
  experiments {
    manifest_resource = true
  }
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

# Simple IAM Policy creation to allow EKS access
module "allow_eks_access_iam_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "5.3.1"

  name          = "allow-eks-access"
  create_policy = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "eks:DescribeCluster",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

# EKS Admin IAM Role
module "eks_admins_iam_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "5.3.1"

  role_name         = "eks-admin"
  create_role       = true
  role_requires_mfa = false

  custom_role_policy_arns = [module.allow_eks_access_iam_policy.arn]

  trusted_role_arns = [
    "arn:aws:iam::${data.terraform_remote_state.network.outputs.vpc_owner_id}:root"
  ]
}

# STS Policy to Assume EKS Admin IAM Role
module "allow_assume_eks_admins_iam_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "5.3.1"

  name          = "allow-assume-eks-admin-iam-role"
  create_policy = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
        ]
        Effect   = "Allow"
        Resource = module.eks_admins_iam_role.iam_role_arn
      },
    ]
  })
}


# EKS Cluster Access IAM Group creation add users in this eks-admin group from AWS IAM Console
# Create IAM Group & attach STS Policy
module "eks_admins_iam_group" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-group-with-policies"
  version = "5.3.1"

  name                              = "eks-admin"
  attach_iam_self_management_policy = false
  create_group                      = true
  custom_group_policy_arns          = [module.allow_assume_eks_admins_iam_policy.arn]
}
