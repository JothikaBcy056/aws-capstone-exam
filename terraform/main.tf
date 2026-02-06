#################################
# Provider (set your region)
#################################
provider "aws" {
  region = "us-east-1"
}

#################################
# Networking
#################################
resource "aws_vpc" "streamline" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "streamline-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.streamline.id
  tags   = { Name = "streamline-igw" }
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.streamline.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true
  tags = { Name = "streamline-public-${count.index}" }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.streamline.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.azs[count.index]
  tags = { Name = "streamline-private-${count.index}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.streamline.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "streamline-public-rt" }
}

resource "aws_route_table_association" "public_assoc" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

#################################
# Security Groups
#################################
resource "aws_security_group" "web_sg" {
  name        = "streamline-web-sg"
  description = "Allow HTTP from anywhere and SSH from office IP"
