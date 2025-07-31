#
# QuantumArb 2.0 - Terraform AWS Infrastructure
#
# File: infra/terraform/aws/main.tf
#
# Description:
# This Terraform configuration provisions the foundational network infrastructure
# for QuantumArb 2.0 on AWS. It creates a Virtual Private Cloud (VPC) designed
# for high performance and security.
#
# This setup includes:
# - A dedicated VPC to isolate our trading infrastructure.
# - Public subnets for internet-facing resources (e.g., load balancers, bastion hosts).
# - Private subnets for the core application services to ensure they are not
#   directly exposed to the internet.
# - An Internet Gateway to allow resources in the public subnets to communicate
#   with the internet.
# - A NAT Gateway to allow resources in the private subnets to initiate outbound
#   connections (e.g., for software updates or API calls) without being
#   publicly accessible.
# - Route tables to control the flow of traffic within the VPC.
#

# --- 1. Define the AWS Provider and Region ---
provider "aws" {
  region = "us-east-1" # N. Virginia is a common region for financial services
}

# --- 2. Create the Virtual Private Cloud (VPC) ---
resource "aws_vpc" "quantum_arb_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "QuantumArb-VPC"
  }
}

# --- 3. Create an Internet Gateway ---
# This is required for resources in the public subnets to access the internet.
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.quantum_arb_vpc.id

  tags = {
    Name = "QuantumArb-IGW"
  }
}

# --- 4. Create Public Subnets ---
# These subnets are for resources that need to be reachable from the internet.
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.quantum_arb_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true // Automatically assign public IPs

  tags = {
    Name = "QuantumArb-Public-Subnet-1a"
  }
}

# --- 5. Create Private Subnets ---
# Core application services (strategy engine, exchange gateways) will reside here.
resource "aws_subnet" "private_subnet_1" {
  vpc_id                  = aws_vpc.quantum_arb_vpc.id
  cidr_block              = "10.0.101.0/24"
  availability_zone       = "us-east-1a"

  tags = {
    Name = "QuantumArb-Private-Subnet-1a"
  }
}

# --- 6. Create a NAT Gateway ---
# This allows instances in the private subnet to access the internet for outbound
# traffic, without being directly exposed. Requires an Elastic IP.
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  depends_on = [aws_internet_gateway.gw]
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_1.id

  tags = {
    Name = "QuantumArb-NAT-Gateway"
  }
  depends_on = [aws_internet_gateway.gw]
}

# --- 7. Configure Route Tables ---
# Public route table: directs internet-bound traffic to the Internet Gateway.
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.quantum_arb_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "QuantumArb-Public-RT"
  }
}

# Private route table: directs internet-bound traffic to the NAT Gateway.
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.quantum_arb_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "QuantumArb-Private-RT"
  }
}

# --- 8. Associate Route Tables with Subnets ---
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_rt.id
}

