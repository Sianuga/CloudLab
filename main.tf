# AWS PROVIDER
provider "aws" {
  region                   = "us-east-1"
  shared_credentials_files = ["C:/Users/dziki/.aws/credentials.txt"]
}

# SET UP VPC
resource "aws_vpc" "my_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "my_vpc"
  }
}

# CREATE SUBNETS
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.101.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  tags = {
    Name = "public_subnet"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.102.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "private_subnet"
  }
}

# CREATE INTERNET GATEWAY
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    name = "my_igw"
  }
}

# CREATE ROUTE TABLES
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public_route_table"
  }
}

# ASSOCIATE ROUTE TABLE WITH PUBLIC SUBNET
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

# CONFIGURE SECURITY GROUPS
resource "aws_security_group" "server_sg" {
  name        = "server_security"
  description = "allow ssh, http traffic"
  vpc_id      = aws_vpc.my_vpc.id


  ingress {
    description = "HTTP Backend"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP Frontend"
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
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg"
  }
}

resource "aws_ecs_cluster" "app_cluster" {
  name = "app_cluster"
}


resource "aws_ecs_task_definition" "app_task" {
family = "app_task"
network_mode = "awsvpc"
requires_compatibilities = ["FARGATE"]
cpu = "512"
memory = "1024"
execution_role_arn = "arn:aws:iam::339712746241:role/LabRole"
task_role_arn = "arn:aws:iam::339712746241:role/LabRole"

container_definitions = jsonencode(
[
    {
      "name": "backend",
      "image": "339712746241.dkr.ecr.us-east-1.amazonaws.com/cloudlab:backend",
      "essential": true,
      "memory": 256,
      "portMappings": [
        {
          "hostPort": 5000,
          "containerPort": 5000
        }
      ]
    },
    {
      "name": "frontend",
      "image": "339712746241.dkr.ecr.us-east-1.amazonaws.com/cloudlab:frontend",
      "essential": true,
      "memory": 256,
      "portMappings": [
        {
          "hostPort": 80,
          "containerPort": 80
        }
      ]
    }
  ]


)

}

resource "aws_ecs_service" "app_service" {
name = "app_service"
cluster = aws_ecs_cluster.app_cluster.id
task_definition = aws_ecs_task_definition.app_task.arn
launch_type = "FARGATE"
desired_count = 1

network_configuration {
  subnets = [aws_subnet.public_subnet.id, aws_subnet.private_subnet.id]
  security_groups = [aws_security_group.server_sg.id]
  assign_public_ip = true
}

depends_on = [aws_ecs_task_definition.app_task]
}

