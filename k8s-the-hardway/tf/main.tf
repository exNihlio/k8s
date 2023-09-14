provider "aws" {
  region = "us-west-2"
}
## Networking
### Subnets
resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr_block
  enable_dns_support = true
  enable_dns_hostnames = true
}
resource "aws_subnet" "this_worker" {
  for_each = var.worker_subnets
  vpc_id = aws_vpc.this.id
  availability_zone = join("", [var.region, each.key])
  cidr_block = cidrsubnet(var.vpc_cidr_block, 12, each.value)
}
##
resource "aws_subnet" "this_bastion" {
  for_each = var.bastion_subnets
  vpc_id = aws_vpc.this.id
  availability_zone = join("", [var.region, each.key])
  cidr_block = cidrsubnet(var.vpc_cidr_block, 12, each.value)
}
### IGW
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
}
### NGW
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.this.id
  subnet_id = aws_subnet.this_worker["a"].id
  depends_on = [aws_internet_gateway.this]
}
### EIP
resource "aws_eip" "this" {
  domain = "vpc"
}
### route tables
resource "aws_route_table" "this_public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
}
resource "aws_route_table" "this_private" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.this.id
  }
}
### route table associations
resource "aws_route_table_association" "this_public"  {
  for_each = aws_subnet.this_bastion
  subnet_id = each.value.id
  route_table_id = aws_route_table.this_public.id
}

resource "aws_route_table_association" "this_private" {
  for_each = aws_subnet.this_worker
  subnet_id = each.value.id
  route_table_id = aws_route_table.this_private.id
}

## Security
### security groups
resource "aws_security_group" "this_bastion" {
  name = "bastion-sg"
  description = "allow ssh from web"
  vpc_id = aws_vpc.this.id
  ingress {
    description = "allow ssh from web"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "allow all egress"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
##
resource "aws_security_group" "this_worker" {
  name = "worker-sg"
  description = "allow ssh from bastion"
  vpc_id = aws_vpc.this.id
  ingress {
    description = "allow ssh from bastion"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    security_groups = [aws_security_group.this_bastion.id]
  }
  egress {
    description = "allow all egress"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
## Instances
#resource "aws_instance" "this_worker" {
#  for_each = aws_subnet.this_worker
#  ami = data.aws_ami.sles15_arm64.id
#  subnet_id = each.value.id
#  instance_type = "t4g.micro"
#  vpc_security_group_ids = [aws_security_group.this_worker.id]
#}
#
resource "aws_instance" "this_bastion" {
  ami = data.aws_ami.opensuse_leap15_arm64.id
  associate_public_ip_address = true
  subnet_id = aws_subnet.this_bastion["a"].id
  instance_type = "t4g.micro"
  user_data = file("cloud-init-bastion.yml")
  vpc_security_group_ids = [aws_security_group.this_bastion.id]
}
