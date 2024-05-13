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



resource "aws_elastic_beanstalk_application" "app" {
  name        = "my-docker-app"
  description = "My Docker Application"
}



resource "aws_elastic_beanstalk_environment" "env" {
  name                = "my-docker-env2"
  application         = aws_elastic_beanstalk_application.app.name
  solution_stack_name = "64bit Amazon Linux 2 v3.3.1 running ECS"
  version_label       = aws_elastic_beanstalk_application_version.version.name
  cname_prefix        = "sianuga-tic-docker"

  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = aws_vpc.my_vpc.id
  }

   setting {
      namespace = "aws:autoscaling:launchconfiguration"
      name      = "IamInstanceProfile"
      value     = "LabInstanceProfile"
    }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = join(",", [aws_subnet.public_subnet.id, aws_subnet.private_subnet.id])
  }

  setting {
      namespace = "aws:ec2:vpc"
      name = "AssociatePublicIpAddress"
      value = "true"
   }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "SecurityGroups"
    value     = aws_security_group.server_sg.id
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "LoadBalanced"
  }

    setting {
      namespace = "aws:elasticbeanstalk:environment"
      name = "ServiceRole"
      value = "arn:aws:iam::339712746241:role/LabRole"
    }

      setting {
        namespace = "aws:ec2:instances"
        name = "SupportedArchitectures"
        value = "x86_64"
      }

      setting {
        namespace = "aws:autoscaling:launchconfiguration"
        name = "InstanceType"
        value = "t2.small"
      }
}


resource "aws_s3_bucket" "app_bucket" {
  bucket = "sianuga2-bucket"
}

resource "aws_s3_object" "app_s3o" {
  bucket = aws_s3_bucket.app_bucket.bucket
  key = "CloudLab.zip"
  source = "CloudLab.zip"
}

resource "aws_elastic_beanstalk_application_version" "version" {
  name        = "v1"
  application = aws_elastic_beanstalk_application.app.name
  description = "Initial version"

  bucket = aws_s3_bucket.app_bucket.bucket  // Correct attribute for specifying the S3 bucket
  key    = aws_s3_object.app_s3o.key   // Correct attribute for specifying the S3 key
}



output "app_url" {
  value = "http://${aws_elastic_beanstalk_environment.env.cname}"
}

