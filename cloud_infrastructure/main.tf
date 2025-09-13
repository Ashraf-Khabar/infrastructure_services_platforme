terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC très simple
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "user-management-vpc"
  }
}

# Subnet public
resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "user-management-public-subnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "user-management-igw"
  }
}

# Route table publique
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "user-management-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Groupe de sécurité
resource "aws_security_group" "app" {
  name        = "user-management-sg"
  description = "Security group for user management app"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "user-management-sg"
  }
}

# Instance EC2
resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.app.id]
  key_name               = aws_key_pair.deployer.key_name

  user_data = templatefile("${path.module}/templates/userdata.sh.tpl", {
    app_directory = "/home/ubuntu/user_management_app"
  })

  tags = {
    Name = "user-management-app"
  }
}

# Adresse IP élastique
resource "aws_eip" "app" {
  instance = aws_instance.app.id
  vpc      = true

  tags = {
    Name = "user-management-eip"
  }
}

# Clé SSH
resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC2nfYVwDi6UGjF3puO2hN2Sb6UU430eVzYMVkFztss5YV/lAJCdp+iaYTC5gncIa+ICiWZ4ghA1OEzQiBWkpGZkIE3pBJr3B6YTIKl6C/utUOvU/alrJUQybayRlO6mUUUdmu6UISFTOAHMmJLf6f2taKqg12WJPOZtmfPq4fRtnuAMWSG4BDLQIso/IK7Pq0nu/pdwiTtje9bWJs88u58LWZZbTU037tF/MGFbDsEyqBJMZqOhgUc/LEcstS+v8eMp9mAtwxhm3AGWmOCc840eL0QmZGn22+t18Ca7TtC/FS0aLQ7CX4zjXv6gCSQuJj5NuqyhPGR2AxdJ+3uWq12TEgLnqe9He3H5siYvFfGRAbft0OzHphDMPc7b99aRkAzVbIqW/wJBFLojJsxuG+KJHHO5F67enlzpR9IBfuz2Y6yCseV/64olnv6EgU2TvhsEcevfrwcO9O1Y1U/57DMfmLP/OjlRaGd+wKnIgykmL3VEP4uQeTr4o91N5UNSdBmQ1HbkyNnp+36ZLnDoP6VC0pyDplj3AE3Kv0eOqljF60uBoSsPp+sOgfSbhYJeCDQ3RYrnwOJEWBlolD+JL2PXU/nJQAP3uOJX2JTqOO+2oCTGw6HOnJqewgHsK3cS0R/WuQN4/3Z34le/gVDYFS09Wo1+Dxb/cQft75dLES/5Q== khabarachraf@gmail.com"
}

# AMI Ubuntu
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu*22.04*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  owners = ["099720109477"]
}