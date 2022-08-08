#Create the VPC
resource "aws_vpc" "Training" {                # Creating VPC here
  cidr_block           = var.training_vpc_cidr # Defining the CIDR block use 10.0.0.0/24 for demo
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  enable_dns_support   = true
}
#Create Internet Gateway and attach it to VPC
resource "aws_internet_gateway" "IGW" { # Creating Internet Gateway
  vpc_id = aws_vpc.Training.id          # vpc_id will be generated after we create VPC
}
#Create a Public Subnets.
resource "aws_subnet" "publicsubnets" { # Creating Public Subnets
  vpc_id                  = aws_vpc.Training.id
  map_public_ip_on_launch = "true"
  availability_zone       = "us-east-1a"
  cidr_block              = var.public_subnets # CIDR block of public subnets
}
#Create a Private Subnet                   # Creating Private Subnets
resource "aws_subnet" "privatesubnets" {
  vpc_id            = aws_vpc.Training.id
  cidr_block        = var.private_subnets # CIDR block of private subnets
  availability_zone = "us-east-1a"
}
#Create a Public Subnets.
resource "aws_subnet" "publicsubnets_2" { # Creating Public Subnets
  vpc_id                  = aws_vpc.Training.id
  map_public_ip_on_launch = "true"
  availability_zone       = "us-east-1b"
  cidr_block              = var.public_subnets_2 # CIDR block of public subnets
}
#Create a Private Subnet                   # Creating Private Subnets
resource "aws_subnet" "privatesubnets_2" {
  vpc_id            = aws_vpc.Training.id
  cidr_block        = var.private_subnets_2 # CIDR block of private subnets
  availability_zone = "us-east-1b"
}
#Route table for Public Subnet's
resource "aws_route_table" "PublicRT" { # Creating RT for Public Subnet
  vpc_id = aws_vpc.Training.id
  route {
    cidr_block = "0.0.0.0/0" # Traffic from Public Subnet reaches Internet via Internet Gateway
    gateway_id = aws_internet_gateway.IGW.id
  }
}
#Route table for Private Subnet's
resource "aws_route_table" "PrivateRT" { # Creating RT for Private Subnet
  vpc_id = aws_vpc.Training.id
  route {
    cidr_block     = "0.0.0.0/0" # Traffic from Private Subnet reaches Internet via NAT Gateway
    nat_gateway_id = aws_nat_gateway.NATgw.id
  }
}
#Route table Association with Public Subnet's
resource "aws_route_table_association" "PublicRTassociation" {
  subnet_id      = aws_subnet.publicsubnets.id
  route_table_id = aws_route_table.PublicRT.id
}
#Route table Association with Private Subnet's
resource "aws_route_table_association" "PrivateRTassociation" {
  subnet_id      = aws_subnet.privatesubnets.id
  route_table_id = aws_route_table.PrivateRT.id
}

#Route table Association with Public Subnet's
resource "aws_route_table_association" "PublicRTassociation2" {
  subnet_id      = aws_subnet.publicsubnets_2.id
  route_table_id = aws_route_table.PublicRT.id
}
#Route table Association with Private Subnet's
resource "aws_route_table_association" "PrivateRTassociation2" {
  subnet_id      = aws_subnet.privatesubnets_2.id
  route_table_id = aws_route_table.PrivateRT.id
}

resource "aws_eip" "nateIP" {
  vpc = true
}
#Creating the NAT Gateway using subnet_id and allocation_id
resource "aws_nat_gateway" "NATgw" {
  allocation_id = aws_eip.nateIP.id
  subnet_id     = aws_subnet.privatesubnets.id
}


resource "aws_key_pair" "Training-key" {
  key_name   = "Training"
  public_key = file("${var.PATH_PUBLIC_KEYPAIR}")
}


resource "aws_db_subnet_group" "postgresql-subnet-group" {
  name       = "postgresql-subnet-group"
  subnet_ids = ["${aws_subnet.privatesubnets.id}", "${aws_subnet.privatesubnets_2.id}"]
}

resource "aws_db_instance" "postgresql-instance" {
  allocated_storage       = 100
  engine                  = "postgres"
  engine_version          = "14.3"
  instance_class          = "db.t3.micro"
  identifier              = "postgresql"
  db_name                 = "db_sonarqube"
  username                = var.DATABASE_USER
  password                = var.DATABASE_PASSWORD
  db_subnet_group_name    = aws_db_subnet_group.postgresql-subnet-group.name
  multi_az                = "false"
  vpc_security_group_ids  = ["${aws_security_group.PostgreSql-sg.id}"]
  storage_type            = "gp2"
  backup_retention_period = 30
  availability_zone       = aws_subnet.privatesubnets.availability_zone
  skip_final_snapshot     = true
}



resource "aws_instance" "ec2_sonarqube" {
  ami                    = "ami-090fa75af13c156b4"
  instance_type          = "t2.medium"
  key_name               = aws_key_pair.Training-key.key_name
  vpc_security_group_ids = [aws_security_group.Training-sg.id]
  subnet_id              = aws_subnet.publicsubnets.id
  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum install git -y",
      "sudo amazon-linux-extras install ansible2 -y",
      "ansible --version",
      "cd /home/ec2-user",
      "git clone https://github.com/carlosmz87/ansible-sonarqube.git",
      "export RDS=${aws_db_instance.postgresql-instance.endpoint}",
      "echo $RDS",
      "cd ansible-sonarqube",
      "ansible-playbook ansible-controller.yml"
    ]
  }
  connection {
    host        = self.public_ip
    user        = var.user_ssh
    private_key = file("${var.PATH_KEYPAIR}")
  }
  depends_on = [
    aws_db_instance.postgresql-instance
  ]
}


resource "aws_security_group" "Training-sg" {
  vpc_id = aws_vpc.Training.id
  name   = "Training-sg"
  egress = [
    {
      cidr_blocks      = ["0.0.0.0/0", ]
      description      = ""
      from_port        = 0
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "-1"
      security_groups  = []
      self             = false
      to_port          = 0
    }
  ]
  ingress = [
    {
      cidr_blocks      = ["0.0.0.0/0", ]
      description      = ""
      from_port        = 22
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "tcp"
      security_groups  = []
      self             = false
      to_port          = 22
    },
    {
      cidr_blocks      = ["0.0.0.0/0", ]
      description      = ""
      from_port        = 9000
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "tcp"
      security_groups  = []
      self             = false
      to_port          = 9000
    }
  ]
}

resource "aws_security_group" "PostgreSql-sg" {
  vpc_id = aws_vpc.Training.id
  name   = "PostgreSql-sg"
  egress = [
    {
      cidr_blocks      = ["0.0.0.0/0", ]
      description      = ""
      from_port        = 0
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "-1"
      security_groups  = []
      self             = false
      to_port          = 0
    }
  ]
  ingress = [
    {
      cidr_blocks      = ["0.0.0.0/0",]
      description      = ""
      from_port        = 5432
      to_port          = 5432
      protocol         = "tcp"
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      self             = false
      security_groups  = ["${aws_security_group.Training-sg.id}"]
    }
  ]
}

