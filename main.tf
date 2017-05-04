# tf_vpc/main.tf

resource "aws_vpc" "vpc" {
  cidr_block = "${var.cidr}"
  enable_dns_hostnames = "${var.enable_dns_hostnames}"
  enable_dns_support = "${var.enable_dns_support}"

  tags {
    Terraform = "true"
    Name = "${var.environment}-vpc"
  }
}

# gateways

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags {
    Terraform = "true"
    Name = "${var.environment}-igw"
  }
}

resource "aws_eip" "ngw_eip" {
  count = "${length(var.public_subnets)}"
  vpc = true
}

resource "aws_nat_gateway" "ngw" {
  count = "${length(var.public_subnets)}"
  allocation_id = "${aws_eip.ngw_eip.*.id[count.index]}"
  subnet_id = "${aws_subnet.public.*.id[count.index]}"
}

# routes

resource "aws_route_table" "public_rt" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags {
    Terraform = "true"
    Name = "${var.environment}-public-rt"
  }
}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = "${aws_route_table.public_rt.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.igw.id}"
}

resource "aws_route_table" "private_rt" {
  count = "${length(var.private_subnets)}"
  vpc_id = "${aws_vpc.vpc.id}"

  tags {
    Terraform = "true"
    Name = "${var.environment}-private-rt"
  }
}

resource "aws_route" "private_nat_gateway" {

  count = "${length(var.private_subnets)}"

  route_table_id         = "${aws_route_table.private_rt.*.id[count.index]}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_nat_gateway.ngw.*.id[count.index]}"
}

# subnets

resource "aws_subnet" "public" {

  count = "${length(var.public_subnets)}"

  vpc_id                  = "${aws_vpc.vpc.id}"
  cidr_block              = "${element(var.public_subnets, count.index)}"
  availability_zone       = "${element(var.azs, count.index)}"
  map_public_ip_on_launch = "${var.map_public_ip_on_launch}"

  tags {
    Terraform             = "true"
    Name                  = "${var.environment}-public"
  }
}

resource "aws_route_table_association" "public" {

  count                   = "${length(var.public_subnets)}"

  subnet_id               = "${element(aws_subnet.public.*.id, count.index)}"
  route_table_id          = "${aws_route_table.public_rt.id}"
}

resource "aws_subnet" "private" {

  count = "${length(var.private_subnets)}"

  vpc_id                  = "${aws_vpc.vpc.id}"
  cidr_block              = "${element(var.private_subnets, count.index)}"
  availability_zone       = "${element(var.azs, count.index)}"
  map_public_ip_on_launch = "false"

  tags {
    Terraform = "true"
    Name = "${var.environment}-private"
  }
}

resource "aws_route_table_association" "private" {

  count = "${length(var.private_subnets)}"

  subnet_id      = "${element(aws_subnet.private.*.id, count.index)}"
  route_table_id = "${aws_route_table.private_rt.*.id[count.index]}"
}

# security groups

resource "aws_security_group" "bastion" {
  vpc_id      = "${aws_vpc.vpc.id}"
  name        = "${var.environment}-bastion"
  description = "Allow SSH to bastion"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "${var.environment}-bastion-sg"
  }
}

resource "aws_security_group" "public" {
  vpc_id      = "${aws_vpc.vpc.id}"
  name        = "${var.environment}-public"
  description = "Allow web services to internet"

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

  tags {
    Name = "${var.environment}-public-sg"
  }
}

resource "aws_security_group" "private" {
  vpc_id      = "${aws_vpc.vpc.id}"
  name        = "${var.environment}-private-sg"
  description = "Allow traffic from public"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    security_groups = ["${aws_security_group.public.id}", "${aws_security_group.bastion.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "${var.environment}-private-sg"
  }
}

# hosts

# bastion host

resource "aws_instance" "bastion" {
  ami                         = "${lookup(var.bastion_ami, var.region)}"
  instance_type               = "${var.bastion_instance_type}"
  key_name                    = "${var.key_name}"
  vpc_security_group_ids      = ["${aws_security_group.bastion.id}"]
  subnet_id                   = "${aws_subnet.public.0.id}"
  associate_public_ip_address = true

  tags {
    Terraform = "true"
    Name = "${var.environment}-bastion"
  }
}

# admin host

#resource "aws_instance" "admin" {
#  ami                         = "${lookup(var.admin_ami, var.region)}"
#  instance_type               = "${var.admin_instance_type}"
#  key_name                    = "${var.key_name}"
#  vpc_security_group_ids      = ["${aws_security_group.private.id}"]
#  subnet_id                   = "${aws_subnet.private.0.id}"
#  associate_public_ip_address = false

#  tags {
#    Terraform = "true"
#    Name = "${var.environment}-admin"
#  }
#}

# terraform host

resource "aws_instance" "terraform" {
  ami                         = "${lookup(var.terraform_ami, var.region)}"
  instance_type               = "${var.terraform_instance_type}"
  key_name                    = "${var.key_name}"
  vpc_security_group_ids      = ["${aws_security_group.private.id}"]
  subnet_id                   = "${aws_subnet.private.0.id}"
  associate_public_ip_address = false

  tags {
    Terraform = "true"
    Name = "${var.environment}-terraform"
  }
}

# spinnaker host

resource "aws_instance" "spinnaker" {
  ami                         = "${lookup(var.spinnaker_ami, var.region)}"
  instance_type               = "${var.spinnaker_instance_type}"
  key_name                    = "${var.key_name}"
  vpc_security_group_ids      = ["${aws_security_group.private.id}"]
  subnet_id                   = "${aws_subnet.private.0.id}"
  associate_public_ip_address = false

  tags {
    Terraform = "true"
    Name = "${var.environment}-spinnaker"
  }
}

# jenkins host

resource "aws_instance" "jenkins" {
  ami                         = "${lookup(var.jenkins_ami, var.region)}"
  instance_type               = "${var.jenkins_instance_type}"
  key_name                    = "${var.key_name}"
  vpc_security_group_ids      = ["${aws_security_group.private.id}"]
  subnet_id                   = "${aws_subnet.private.0.id}"
  associate_public_ip_address = false

  tags {
    Terraform = "true"
    Name = "${var.environment}-jenkins"
  }
}
