provider "aws" {
region = "ap-south-1"
profile = "pushkar1"
}
variable "mykey" {
	type = string
	default = "mykey121"
}


resource "aws_vpc" "myvpc1" {
  cidr_block = "192.168.0.0/16"
  enable_dns_hostnames = "true"

  tags = {
    Name = "MyVpc"
  }
}

resource "aws_subnet" "public_subnet" {
  depends_on = [
    aws_vpc.myvpc1,
  ]
  vpc_id     = aws_vpc.myvpc1.id
  cidr_block = "192.168.2.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = "true"

  tags = {
    Name = "Public Subnet"
  }
}

resource "aws_subnet" "private_subnet" {
  depends_on = [
    aws_vpc.myvpc1,
  ]
  vpc_id     = aws_vpc.myvpc1.id
  cidr_block = "192.168.1.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "Private Subnet"
  }
}

resource "aws_internet_gateway" "gw" {
  depends_on = [
    aws_vpc.myvpc1,
  ]
  vpc_id = aws_vpc.myvpc1.id

  tags = {
    Name = "Internet gateway"
  }
}


resource "aws_route_table" "my_route_table1" {
  depends_on = [
    aws_vpc.myvpc1,
  ]
  vpc_id = aws_vpc.myvpc1.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  
  tags = {
    Name = "Routing Table"
  }
}

resource "aws_route_table_association" "Route_association" {
  depends_on = [
    aws_route_table.my_route_table1,
  ]
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.my_route_table1.id
}



resource "aws_security_group" "Wordpress_sg" {

  name        = "Wordpress_sg"
  description = "Allow Tcp $ Ssh inbound traffic"
  vpc_id      = aws_vpc.myvpc1.id
  

  ingress {
    description = "Ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
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
    Name = "allow_SSh_http"
  }
}

resource "aws_security_group" "MySql_sg" {
  name        = "MySq_sg"
  description = "Allow Wordpress inbound traffic"
  vpc_id      = aws_vpc.myvpc1.id
  

  
 ingress {
    description = "Allow MySql"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    
  }
 ingress {
    description = "Ssh"
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
    Name = "allow_MySql"
  }
}



resource "aws_instance" "mysql"{
   depends_on = [
    aws_vpc.myvpc1,aws_security_group.MySql_sg,
  ]
ami   = "ami-0019ac6129392a0f2"
instance_type = "t2.micro"
vpc_security_group_ids = [ aws_security_group.MySql_sg.id]
subnet_id = aws_subnet.private_subnet.id
/*user_data = <<-EOF
#!/bin/bash
sudo docker run -dit -p 80:3306 --name mysql -e MYSQL_ROOT_PASSWORD=****** -e MYSQL_DATABASE=DB -e MYSQL_USER=******* -e MYSQL_PASSWORD=******8 mysql:5.6
EOF
tags = {
 Name = "MySqlOS"
  }*/
} 



resource "aws_instance" "webpage"{
  depends_on = [
    aws_vpc.myvpc1,aws_security_group.Wordpress_sg,
  ]
ami   = "ami-000cbce3e1b899ebd"
instance_type = "t2.micro"
associate_public_ip_address = "true"
availability_zone = "ap-south-1a"
key_name = var.mykey
vpc_security_group_ids = [ aws_security_group.Wordpress_sg.id]
subnet_id = aws_subnet.public_subnet.id
/*user_data = <<-EOF
#!/bin/bash
sudo docker run -dit -p 80:80 --name wp wordpress:4.8-apache
EOF
tags = {
 Name = "wpOS"
  }*/
} 

resource "null_resource" "nullremote2"  {
  depends_on = [
    aws_instance.webpage,
  ]
connection{
  type= "ssh"
  user = "bitnami"
  host     = aws_instance.webpage.public_ip
  private_key = file    ("C:/Users/Lenovo/Desktop/mykey121.pem")
}
  provisioner "remote-exec" {
    inline = ["sudo /opt/bitnami/ctlscript.sh restart apache",
    "sudo /opt/bitnami/ctlscript.sh status",
    ]
  
  }


provisioner "local-exec" {
	    command = "start chrome  ${aws_instance.webpage.public_ip}"
  	}
}
