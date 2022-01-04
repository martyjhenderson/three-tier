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

## VPCs 
resource "aws_vpc" "main"  {
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

resource "aws_security_group" "pg-sg"{

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

## EC2 Instance
resource "aws_instance" "webwebserver1" {
  ami                    = "ami-0d5eff06f840b45e9"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.webserver-sg.id]
  subnet_id              = aws_subnet.public_subnets
  tags = {
    Name = "mjh-demo"
  }
}

## RDS Instance

resource "aws_db_instance" "pg-db" {
  allocated_storage         = 5
  engine                    = "postgres"
  engine_version            = "13.4"
  instance_class            = "db.t2.micro"
  name                      = "pg-db"
  username                  = "${var.database_user}"
  password                  = "${var.database_password}"
  db_subnet_group_name      = aws_vpc.main.database_subnets
  vpc_security_group_ids    = ["${aws_security_group.rds.id}"]
}