terraform {
  cloud {
    organization = "arun-cloud-whiz" # Found in your dashboard breadcrumbs

    workspaces {
      name = "hcp-vcs-lab" # Found in your workspace settings
    }
  }
}
provider "aws" {
  region = "ap-south-1"
}
resource "aws_vpc" "rl-vpc" {
  cidr_block = var.aws_cidr
  enable_dns_hostnames = true   
  enable_dns_support = true
  tags = {
    Name =  "MY-VPC"
  }
}
resource "aws_subnet" "public-subnet1" {
  vpc_id            = aws_vpc.my-vpc.id
  cidr_block        = "192.168.0.0/25"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = { Name = "public-subnet1" }
}
resource "aws_subnet" "public-subnet2" {
  vpc_id            = aws_vpc.my-vpc.id
  cidr_block        = "192.168.0.128/25"
  availability_zone = "ap-south-1b"
  map_public_ip_on_launch = true  

  tags = { Name = "public-subnet2" }
}
resource "aws_internet_gateway" "my-igw" {
  vpc_id = aws_vpc.my-vpc.id
  tags = {
    Name = "my-igw"
  }
}
resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.my-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my-igw.id
  }
  tags = {
    Name = "public-route-table"
  }
}
resource "aws_route_table_association" "public-subnet1-assoc" {
  subnet_id      = aws_subnet.public-subnet1.id
  route_table_id = aws_route_table.public-rt.id
}

resource "aws_route_table_association" "public-subnet2-assoc" {
  subnet_id      = aws_subnet.public-subnet2.id
  route_table_id = aws_route_table.public-rt.id
}
resource "aws_security_group" "EC2-SG" {
  name        = "allow-all"
  description = "Allow all inbound and outbound traffic"
  vpc_id      = aws_vpc.my-vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
# IMPORTANT for EFS
  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "EC2-SG"
  }
}
//Create EC2 Instance
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}
/*
resource "aws_efs_file_system" "my_efs" {
  creation_token = "my-efs"

  throughput_mode = "bursting"   # IMPORTANT
  performance_mode = "generalPurpose"

  tags = {
    Name = "my-efs"
  }
}
resource "aws_efs_mount_target" "efs_mount" {
  file_system_id  = aws_efs_file_system.my_efs.id
  subnet_id       = aws_subnet.public-subnet1.id
  security_groups = [aws_security_group.EC2-SG.id]
}
*/
resource "aws_instance" "my-ec2" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public-subnet1.id
  vpc_security_group_ids      = [aws_security_group.EC2-SG.id]
  associate_public_ip_address = true

  # Minimal root EBS (required by AWS)
  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }
  user_data = <<-EOF
              #!/bin/bash
              yum install docker -y
              systemctl start docker
              systemctl enable docker
              usermod -aG docker ec2-user
              docker run -d --name mywebsite -p 80:80 gangassault343/weather-app-php:latest
              
              EOF
  /*
  user_data = <<-EOF
              #!/bin/bash
              yum install -y amazon-efs-utils

              mkdir -p /mnt/efs

              mount -t efs ${aws_efs_file_system.my_efs.id}:/ /mnt/efs

              echo "${aws_efs_file_system.my_efs.id}:/ /mnt/efs efs defaults,_netdev 0 0" >> /etc/fstab
              EOF

  */
  tags = {
    Name = "my-ec2-instance1"
  }
/*
  depends_on = [
    aws_efs_mount_target.efs_mount
  ]
*/
}
