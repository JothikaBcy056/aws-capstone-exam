#################################
# Provider
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
  description = "Allow HTTP from anywhere and SSH from specific IP"
  vpc_id      = aws_vpc.streamline.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["43.205.230.28/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "streamline-web-sg" }
}

resource "aws_security_group" "db_sg" {
  name        = "streamline-db-sg"
  description = "Allow MySQL from web_sg"
  vpc_id      = aws_vpc.streamline.id

  ingress {
    description     = "MySQL from web instances"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "streamline-db-sg" }
}

#################################
# RDS (MySQL) in private subnets
#################################
resource "aws_db_subnet_group" "db_subnet" {
  name       = "streamline-db-subnet"
  subnet_ids = aws_subnet.private[*].id
  tags       = { Name = "streamline-db-subnet" }
}

resource "aws_db_instance" "mysql" {
  # Engine
  engine          = "mysql"
  engine_version  = "8.0"

  # Size / class
  allocated_storage = 20
  instance_class    = "db.t3.micro"

  # Identifiers & credentials
  identifier  = "streamlinedb"   # RDS instance name in AWS
  db_name     = "streamlinedb"   # Initial DB created inside MySQL
  username    = "admin"
  password    = "password123"    # For demonstrations only

  # Networking
  db_subnet_group_name   = aws_db_subnet_group.db_subnet.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  publicly_accessible    = false
  skip_final_snapshot    = true

  tags = { Name = "streamline-mysql" }
}

#################################
# EC2 Web Instances (public)
#################################
# NOTE: Replace AMI if invalid in your region.
resource "aws_instance" "web" {
  count                       = 2
  ami                         = "ami-0b6c6ebed2801a5cb" # Amazon Linux 2 (might be outdated)
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public[count.index].id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true

  tags = { Name = "web-${count.index}" }
}

#################################
# ALB and Target Group
#################################
resource "aws_lb" "alb" {
  name               = "streamline-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = aws_subnet.public[*].id
  security_groups    = [aws_security_group.web_sg.id]

  tags = { Name = "streamline-alb" }
}

resource "aws_lb_target_group" "tg" {
  name     = "streamline-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.streamline.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    timeout             = 5
  }

  tags = { Name = "streamline-tg" }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

resource "aws_lb_target_group_attachment" "attach" {
  count            = 2
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.web[count.index].id
  port             = 80
}
``
