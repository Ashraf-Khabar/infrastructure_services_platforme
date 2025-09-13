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

# Utilisation d'une VPC existante au lieu d'en créer une nouvelle
data "aws_vpc" "existing" {
  default = true  # Utilise la VPC par défaut
}

# Utilisation d'un subnet existant dans la VPC par défaut
data "aws_subnets" "existing" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }
}

data "aws_subnet" "selected" {
  id = element(data.aws_subnets.existing.ids, 0)
}

# Internet Gateway existant (généralement déjà présent dans la VPC par défaut)
data "aws_internet_gateway" "existing" {
  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_vpc.existing.id]
  }
}

# Route table existante
data "aws_route_table" "existing" {
  vpc_id = data.aws_vpc.existing.id
  
  filter {
    name   = "association.main"
    values = ["true"]
  }
}

# Groupe de sécurité
resource "aws_security_group" "app" {
  name        = "user-management-sg"
  description = "Security group for user management app"
  vpc_id      = data.aws_vpc.existing.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access"
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "App API access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "user-management-sg"
  }
}

# Clé SSH avec nom unique pour éviter les conflits
resource "aws_key_pair" "deployer" {
  key_name   = "user-management-deployer-key-${formatdate("YYYYMMDD", timestamp())}"
  public_key = file("~/.ssh/id_rsa.pub")

  tags = {
    Name = "user-management-deployer-key"
  }
}

# Instance EC2
resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnet.selected.id
  vpc_security_group_ids = [aws_security_group.app.id]
  key_name               = aws_key_pair.deployer.key_name

  user_data = templatefile("${path.module}/templates/userdata.sh.tpl", {
    app_directory = "/home/ubuntu/user_management_app"
  })

  tags = {
    Name = "user-management-app"
  }

  # Assure que l'IP publique est assignée
  associate_public_ip_address = true
}

# Adresse IP élastique (optionnel - seulement si besoin d'IP fixe)
resource "aws_eip" "app" {
  instance = aws_instance.app.id
  vpc      = true

  tags = {
    Name = "user-management-eip"
  }
}

# AMI Ubuntu
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-22.04-*-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  owners = ["099720109477"] # Canonical
}