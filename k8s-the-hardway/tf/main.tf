provider "aws" {
  region = "us-west-2"
}
locals {
  terraform_git_repo = "k8s"
  terraform_base_path = replace(path.cwd, "/^.*?(${local.terraform_git_repo}\\/)/", "$1")
  default_tags = {
    terraform_git_repo = local.terraform_git_repo
    terraform_base_path = local.terraform_base_path
    created_by = "exNihlio"
    project = "k8s"
  }
}
## Networking
### Subnets
resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr_block
  enable_dns_support = true
  enable_dns_hostnames = true
}
resource "aws_subnet" "this_private" {
  count = 3
  vpc_id = aws_vpc.this.id
  availability_zone = data.aws_availability_zones.azs.names[count.index]
  cidr_block = cidrsubnet(var.vpc_cidr_block, 12, count.index)
  tags = merge(local.default_tags,
    { Name = "private-subnet-${count.index}",
      availability_zone = data.aws_availability_zones.azs.names[count.index]})
}
##
resource "aws_subnet" "this_public" {
  vpc_id = aws_vpc.this.id
  availability_zone = data.aws_availability_zones.azs.names[0]
  cidr_block = cidrsubnet(var.vpc_cidr_block, 12, 3)
  tags = merge(local.default_tags,
    { Name = "public-subnet-${data.aws_availability_zones.azs.names[0]}",
      availability_zone = data.aws_availability_zones.azs.names[0]})
}
### IGW
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
}
### NGW
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.this.id
  subnet_id = aws_subnet.this_public.id
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
  subnet_id = aws_subnet.this_public.id
  route_table_id = aws_route_table.this_public.id
}

resource "aws_route_table_association" "this_private" {
  count = 3
  subnet_id = aws_subnet.this_private[count.index].id
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
  ingress {
    description = "allow ICMP"
    from_port = -1
    to_port = -1
    protocol = "icmp"
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
## Instances
resource "aws_instance" "this_worker" {
  count = 3
  ami = data.aws_ami.opensuse_leap15_arm64.id
  subnet_id = aws_subnet.this_private[count.index].id
  instance_type = "t4g.micro"
  user_data = file("cloud-init-worker.yml")
  user_data_replace_on_change = true
  vpc_security_group_ids = [aws_security_group.this_worker.id]
  tags = merge(local.default_tags, {Name = "worker-${count.index}"})
}

resource "aws_instance" "this_controller" {
  count = 3
  ami = data.aws_ami.opensuse_leap15_arm64.id
  subnet_id = aws_subnet.this_private[count.index].id
  instance_type = "t4g.nano"
  user_data = file("cloud-init-worker.yml")
  user_data_replace_on_change = true
  vpc_security_group_ids = [aws_security_group.this_worker.id]
  tags = merge(local.default_tags, {Name = "controller-${count.index}"})
}
#
resource "aws_instance" "this_bastion" {
  ami = data.aws_ami.opensuse_leap15_arm64.id
  associate_public_ip_address = true
  subnet_id = aws_subnet.this_public.id
  instance_type = "t4g.micro"
  user_data = file("cloud-init-bastion.yml")
  user_data_replace_on_change = true
  vpc_security_group_ids = [aws_security_group.this_bastion.id]
  tags = merge(local.default_tags,{Name = "k8s-bastion"})
}

## Route53

resource "aws_route53_zone" "this" {
  name = "example.com"
  vpc {
    vpc_id = aws_vpc.this.id
  }
}

resource "aws_route53_record" "this_worker" {
  count = 3
  zone_id = aws_route53_zone.this.zone_id
  name = aws_instance.this_worker[count.index].tags_all["Name"]
  records = [aws_instance.this_worker[count.index].private_ip]
  type = "A"
  ttl = 300
}

resource "aws_route53_record" "this_controller" {
  count = 3
  zone_id = aws_route53_zone.this.zone_id
  name = aws_instance.this_controller[count.index].tags_all["Name"]
  records = [aws_instance.this_worker[count.index].private_ip]
  type = "A"
  ttl = 300
}

resource "aws_route53_record" "this_bastion" {
  zone_id = data.aws_route53_zone.this_public.zone_id
  name     = aws_instance.this_bastion.tags_all["Name"]
  records = [aws_instance.this_bastion.public_ip]
  type = "A"
  ttl = 300
}
