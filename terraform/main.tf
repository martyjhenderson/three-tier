terraform {
  required_version  = "1.0.11"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}


module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 2"

  name = "mjh-demo-vpc"
  cidr = "10.0.0.0/18"

  azs              = ["${aws.region}a", "${aws.region}b", "${aws.region}c"]
  public_subnets   = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
  private_subnets  = ["10.0.3.0/24", "10.0.4.0/24", "10.0.5.0/24"]
  database_subnets = ["10.0.7.0/24", "10.99.8.0/24", "10.0.9.0/24"]

  create_database_subnet_group = true

}

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

resource "aws_route_table_association" "rt_assoc_1a" {
  subnet_id      = aws_subnet.pub_subnet_1a.id
  route_table_id = aws_route_table.pub_rt.id
}

resource "aws_route_table_association" "rt_assoc_1b" {
  subnet_id      = aws_subnet.pub_subnet_1b.id
  route_table_id = aws_route_table.pub_rt.id
}

resource "aws_security_group" "general_sg" {
  description = "HTTP egress to anywhere"
  vpc_id      = aws_vpc.main.id

  tags = {
    Project = "mjh-demo"
  }
}

resource "random_pet" "bucket_name" {
}

resource "aws_s3_bucket" "s3_backend" {
    bucket = "s3_backend_${random_pet.server.id}" 
    acl = "private"   
}

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4"

  name        = "postgres-sg"
  description = "PostgreSQL security group"
  vpc_id      = module.vpc.vpc_id

  # ingress
  ingress_with_cidr_blocks = [
    {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      description = "PostgreSQL access"
      cidr_blocks = module.vpc.vpc_cidr_block
    },
  ]
}