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

#  Use existing VPC (update the ID if needed)
data "aws_vpc" "existing" {
  id = "vpc-074e57ae1b4e8e5d4"
}

#  Create a new Internet Gateway attached to that VPC
resource "aws_internet_gateway" "this" {
  vpc_id = data.aws_vpc.existing.id

  tags = {
    Name = "user-management-igw"
  }
}

#  Get latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

#  Create Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = data.aws_vpc.existing.id
  cidr_block              = var.subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "user-management-public-subnet"
  }
}

#  Create Route Table and attach IGW
resource "aws_route_table" "public" {
  vpc_id = data.aws_vpc.existing.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "user-management-public-rt"
  }
}

#  Associate Route Table with Subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

#  Security Group
resource "aws_security_group" "app" {
  name        = "user-management-sg-${formatdate("YYYYMMDD", timestamp())}"
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

  ingress {
    from_port   = 8083
    to_port     = 8083
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "App Client access"
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

#  Key Pair
resource "aws_key_pair" "deployer" {
  key_name   = "user-management-deployer-key-${formatdate("YYYYMMDD-hhmmss", timestamp())}"
  public_key = file("~/.ssh/id_rsa.pub")

  tags = {
    Name = "user-management-deployer-key"
  }
}

#  EC2 Instance
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

  associate_public_ip_address = true
}

#  Elastic IP
resource "aws_eip" "app" {
  instance = aws_instance.app.id
  vpc      = true

  tags = {
    Name = "user-management-eip"
  }
}
