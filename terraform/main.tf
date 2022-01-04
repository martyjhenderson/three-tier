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

resource "aws_vpc" "main" {
  cidr_block = "10.10.0.0/16"

  tags = {
    Project = "mjh-demo"
  }
}

resource "aws_subnet" "pub_subnet_1a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.10.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Project = "mjh-demo"
  }
}

resource "aws_subnet" "pub_subnet_1b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.10.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Project = "mjh-demo"
  }
}

resource "aws_subnet" "prv_subnet_1a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.10.3.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false

  tags = {
    Project = "mjh-demo"
  }
}

resource "aws_subnet" "prv_subnet_1b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.10.4.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = false

  tags = {
    Project = "mjh-demo"
  }
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