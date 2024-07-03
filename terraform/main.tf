provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "s3" {
    bucket = "troy-nonprod-01"
    key    = "terraform/terraform.tfstate"
    region = "us-east-1"
  }
}

variable "vpc_name" {
  description = "The name of the VPC"
  type        = string
}

variable "key_name" {
  description = "The name of the SSH key pair"
  type        = string
}

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = var.vpc_name
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.vpc_name}-igw"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.vpc_name}-public-subnet"
  }
}

resource "aws_subnet" "private_subnet1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "${var.vpc_name}-private-subnet1"
  }
}

resource "aws_subnet" "private_subnet2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "${var.vpc_name}-private-subnet2"
  }
}

resource "aws_nat_gateway" "nat1" {
  allocation_id = aws_eip.nat1.id
  subnet_id     = aws_subnet.public_subnet.id
  tags = {
    Name = "${var.vpc_name}-nat1"
  }
}

resource "aws_eip" "nat1" {
  vpc = true
  tags = {
    Name = "${var.vpc_name}-eip-nat1"
  }
}

resource "aws_security_group" "allow_ssh" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
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
    Name = "${var.vpc_name}-allow-ssh"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "${var.vpc_name}-public-rt"
  }
}

resource "aws_route_table_association" "public_rt_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt1" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat1.id
  }
  tags = {
    Name = "${var.vpc_name}-private-rt1"
  }
}

resource "aws_route_table" "private_rt2" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat1.id
  }
  tags = {
    Name = "${var.vpc_name}-private-rt2"
  }
}

resource "aws_route_table_association" "private_rt1_assoc" {
  subnet_id      = aws_subnet.private_subnet1.id
  route_table_id = aws_route_table.private_rt1.id
}

resource "aws_route_table_association" "private_rt2_assoc" {
  subnet_id      = aws_subnet.private_subnet2.id
  route_table_id = aws_route_table.private_rt2.id
}

resource "aws_instance" "public_instance" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet.id
  associate_public_ip_address = true
  key_name      = var.key_name
  security_groups = [aws_security_group.allow_ssh.name]

  tags = {
    Name = "${var.vpc_name}-public-instance"
  }
}

resource "aws_instance" "private_instance1" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private_subnet1.id
  associate_public_ip_address = false
  key_name      = var.key_name
  security_groups = [aws_security_group.allow_ssh.name]

  tags = {
    Name = "${var.vpc_name}-private-instance1"
  }
}

resource "aws_instance" "private_instance2" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private_subnet2.id
  associate_public_ip_address = false
  key_name      = var.key_name
  security_groups = [aws_security_group.allow_ssh.name]

  tags = {
    Name = "${var.vpc_name}-private-instance2"
  }
}
