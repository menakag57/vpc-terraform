#Provider terraform block
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "ap-southeast-1"
}

#vpc
resource "aws_vpc" "myvpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "My-vpc"
  }
}

#subnets(pub &pri)
resource "aws_subnet" "pubsub" {
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-southeast-1a"

  tags = {
    Name = "Pub-sub"
      }
}

#subnets(pub &pri)
resource "aws_subnet" "prisub" {
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "ap-southeast-1b"

  tags = {
    Name = "Pri-sub"
      }

  }

#internet gateway
resource "aws_internet_gateway" "myigw" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "My-IGW"
  }
}
#public route table
resource "aws_route_table" "pubrt" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myigw.id
  }
   
  tags = {
    Name = "PUB-RT"
  }
}
#private route table
resource "aws_route_table" "prirt" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.mynat.id
  }
   
  tags = {
    Name = "PRI-RT"
  }
} 

#subnet association
resource "aws_route_table_association" "pubrtaso" {
  subnet_id      = aws_subnet.pubsub.id
  route_table_id = aws_route_table.pubrt.id
}

resource "aws_route_table_association" "prirtaso" {
  subnet_id      = aws_subnet.prisub.id
  route_table_id = aws_route_table.prirt.id
}

# SG
resource "aws_security_group" "pubsg" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    description      = "ALL TCP"
    from_port        = 0
    to_port          = 62535
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
        #ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    #ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "pub-sg"
  }
}

resource "aws_security_group" "prisg" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    description      = "ALL TCP"
    from_port        = 0
    to_port          = 62535
    protocol         = "tcp"
    cidr_blocks      = ["aws_security_group.prisg.id"]
        #ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    #ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "pri-sg"
  }
}

#E-IP
resource "aws_eip" "myeip" {
  vpc      = true
}

#nat gateway
resource "aws_nat_gateway" "mynat" {
  allocation_id = aws_eip.myeip.id
  subnet_id     = aws_subnet.pubsub.id

  tags = {
    Name = "MY-NAT"
  }
}

#web server & app server
resource "aws_instance" "webser" {
  ami           = "ami-0b0f138edf421d756"
  instance_type = "t3.micro"
  associate_public_ip_address = true
  subnet_id   = aws_subnet.pubsub.id
  vpc_security_group_ids =["${aws_security_group.pubsg.id}"]

  tags = {
    Name = "WEBSERVER"
  }
}

resource "aws_instance" "appser" {
  ami           = "ami-0b0f138edf421d756"
  instance_type = "t3.micro"
  associate_public_ip_address = true
  subnet_id   = aws_subnet.prisub.id
  vpc_security_group_ids =["${aws_security_group.prisg.id}"]
  
  tags = {
    Name = "App server"
  }
}