terraform {
  required_version = "1.0.11"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
    kustomization = {
      source  = "kbst/kustomize"
      version = "0.2.0-beta.3"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

## VPCs 
resource "aws_vpc" "main" {
  cidr = "10.0.0.0/18"

  azs              = ["${aws.region}a", "${aws.region}b", "${aws.region}c"]
  public_subnets   = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
  private_subnets  = ["10.0.3.0/24", "10.0.4.0/24", "10.0.5.0/24"]
  database_subnets = ["10.0.7.0/24", "10.99.8.0/24", "10.0.9.0/24"]

  create_database_subnet_group = true

}

## IGW and Public Routing
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Project = "mjh-demo"
  }
}

resource "aws_route_table" "pub_route" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Project = "mjh-demo"
  }
}

resource "aws_route_table_association" "rt_assoc_pub" {
  subnet_id      = aws_vpc.main.public_subnets
  route_table_id = aws_route_table.pub_rt.id
}

## Security groups

resource "aws_security_group" "pg-sg" {

  description = "PostgreSQL security group"
  vpc_id      = aws_vpc.vpc.vpc_id

  # ingress
  ingress_with_cidr_blocks = [
    {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      description = "PostgreSQL access"
      cidr_blocks = aws_vpc.vpc.vpc_cidr_block
    },
  ]
}



## RDS Instance

resource "random_password" "db_pass" {
  length  = 16
  special = true
}

resource "aws_db_instance" "pg-db" {
  allocated_storage      = 5
  engine                 = "postgres"
  engine_version         = "13.4"
  instance_class         = "db.t2.micro"
  name                   = "pg-db"
  username               = var.database_user
  password               = random_password.db_pass.result
  db_subnet_group_name   = aws_vpc.main.database_subnets
  vpc_security_group_ids = aws_security_group.pg-sg
}

## EKS

resource "aws_iam_role" "eks-cluster" {
  name = "eks-cluster-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "e2e-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks-cluster.name
}

resource "aws_iam_role_policy_attachment" "e2e-cluster-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks-cluster.name
}

resource "aws_security_group" "e2e-cluster" {
  name        = "terraform-eks-demo-cluster"
  description = "Cluster communication with worker nodes"
  vpc_id      = aws_vpc.main.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mjh-demo"
  }
}

resource "aws_iam_role" "eks-node" {
  name = "eks-node"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    },
    {
    "Effect": "Allow",
    "Action": [
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupIngress"
    ],
    "Resource": "*"
},
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "eks-node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks-node.name
}

resource "aws_iam_role_policy_attachment" "eks-node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks-node.name
}

resource "aws_iam_role_policy_attachment" "eks-node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks-node.name
}

resource "aws_iam_instance_profile" "eks-node" {
  name = "e2e"
  role = aws_iam_role.eks-node.name
}

resource "aws_iam_role" "eks-demo-cluster" {
  name = "eks-demo-cluster"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "eks-demo-cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks-demo-cluster.name
}

resource "aws_iam_role_policy_attachment" "eks-demo-cluster-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks-demo-cluster.name
}

resource "aws_eks_cluster" "eks-demo" {
  name     = var.cluster-name
  role_arn = aws_iam_role.eks-demo-cluster.arn

  vpc_config {
    security_group_ids = aws_security_group.eks-cluster.id
    subnet_ids         = aws_subnet.private_subnets.*.id
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks-cluster-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks-cluster-AmazonEKSServicePolicy,
  ]
}
resource "aws_security_group" "eks-node" {
  name        = "eks-demo-node"
  description = "Security group for all nodes in the cluster"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Project = "mjh-demo"
  }
}

resource "aws_security_group_rule" "eks-ingress-self" {
  description              = "Allow node to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.eks-node.id
  source_security_group_id = aws_security_group.eks-node.id
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "eks-ingress-cluster" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 1025
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks-node.id
  source_security_group_id = aws_security_group.eks-cluster.id
  to_port                  = 65535
  type                     = "ingress"
}
resource "aws_security_group_rule" "eks-cluster-ingress-node-https" {
  description              = "Allow pods to communicate with the cluster API Server"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks-cluster.id
  source_security_group_id = aws_security_group.eks-node.id
  to_port                  = 443
  type                     = "ingress"
}

resource "aws_launch_configuration" "eks-demo" {
  associate_public_ip_address = true
  instance_type               = "m4.large"
  name_prefix                 = "eks-demo"
  security_groups             = aws_security_group.eks-node.id

  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_autoscaling_group" "eks-demo" {
  desired_capacity     = 2
  launch_configuration = aws_launch_configuration.demo.id
  max_size             = 2
  min_size             = 1
  name                 = "terraform-eks-demo"
  vpc_zone_identifier  = aws_subnet.private_subnets.*.id

  tags = {
    Project = "mjh-demo"
  }
}

## LB

## See [Apply ALB Controller](alb-controller.md)

## Note that we can't get this info until AFTER the cluster is created
provider "helm" {
  kubernetes {
    host = aws_eks_cluster.eks-demo.cluster_endpoint
    exec {
      api_version = "client.authentication.k8s.io/v1alpha1"
      args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.eks-demo.cluster_name]
      command     = "aws"
    }
  }
}

provider "kustomization" {}


data "kustomization" "alb-TargetGroupBinding" {
  provider = kustomization
  path     = "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"
}

resource "kustomization_resource" "alb-TargetGroupBinding" {
  provider = kustomization
  for_each = data.kustomization.test.ids
  manifest = data.kustomization.test.manifests[each.value]
}



resource "aws_iam_policy" "example" {
  policy = data.aws_iam_policy_document.iam-policy.json
}

resource "helm_release" "nginx_ingress" {
  name = "eks-alb"

  repository = "https://aws.github.io/eks-charts"
  chart      = "eks/aws-load-balancer-controller"

  set {
    name  = "clusterName"
    value = aws_eks_cluster.eks-demo.cluster-name
  }
}
