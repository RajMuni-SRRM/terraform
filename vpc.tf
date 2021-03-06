====================providers.tf===================
provider "aws" {
    access_key="Your IAM user access_key"
    secret_key="Your IAM user secret_key"
    region=var.REGION
}


======================Var.tf==========================

variable REGION {
        default = "us-west-1"
}

variable ZONE1 {
        default = "us-west-1a"
}

variable ZONE1 {
        default = "us-west-1c"
}

variable AMIS {
        type = map
        default = {
                us-west-1 = "ami-0a245a00f741d6301"
        }
}

variable PRIV_KEY {
        default = "dinokey"
}

variable PUB_KEY {
        default = "dinokey.pub"
}

variable EC2-USER {
	default = "ec2-user"
}

=============================VPC.tf=======================================
#VPC Creation

resource "aws_vpc" "SRRM-VPC" {
        cidr_block       = "10.43.14.0/24"
        instance_tenancy = "default"
        enable_dns_support = "true" #gives you an internal domain name
        enable_dns_hostnames = "true" #gives you an internal host name
        tags = {
                Name = "SRRM-VPC"
        }
}

#Private subnet creation

resource "aws_subnet" "SRRM-VPC-PRIV-SUB" {
        vpc_id = aws_vpc.SRRM-VPC.id
        cidr_block = "10.43.14.0/25"
        map_public_ip_on_launch = "false" #it makes this a public subnet
        availability_zone = "us-west-1a"
        tags = {
                Name = "SRRM-VPC-PRIV-SUB"
        }
}

#Public subnet creation

resource "aws_subnet" "SRRM-VPC-PUB-SUB" {
    vpc_id = aws_vpc.SRRM-VPC.id
    cidr_block = "10.43.14.128/25"
    availability_zone = "us-west-1c"
	map_public_ip_on_launch = "true"
    tags = {
        Name = "SRRM-VPC-PUB-SUB"
    }
}


# Creation of Internet Gateway

resource "aws_internet_gateway" "SRRM-IGW" {
    vpc_id = aws_vpc.SRRM-VPC.id
    tags = {
        Name = "SRRM-IGW"
    }
}

#Creation Route Table

resource "aws_route_table" "SRRM-RT" {
    vpc_id = aws_vpc.SRRM-VPC.id
	route {
        //associated subnet can reach everywhere
        cidr_block = "0.0.0.0/0"
        //CRT uses this IGW to reach internet
        gateway_id = aws_internet_gateway.SRRM-IGW.id
    }

    tags = {
        Name = "SRRM-RT"
    }
}

#Associate Route table with subnet

resource "aws_route_table_association" "SRRM-RT-SUB-ASSO" {
    subnet_id = aws_subnet.SRRM-VPC-PUB-SUB.id
    route_table_id = aws_route_table.SRRM-RT.id
}

#Create EC2

resource "aws_instance" "web1" {
    ami = var.AMIS[var.REGION]
    instance_type = "t2.micro"
    # VPC
    subnet_id = aws_subnet.SRRM-VPC-PUB-SUB.id
    # Security Group
    vpc_security_group_ids = [aws_security_group.SRRM-VPC-SG.id]
    # the Public SSH key
    key_name = aws_key_pair.CAL-KEY-PAIR.id
    # httpd installation
    provisioner "file" {
        source = "httpd.sh"
        destination = "/tmp/httpd.sh"
    }
    provisioner "remote-exec" {
        inline = [
             "chmod +x /tmp/httpd.sh",
             "sudo /tmp/httpd.sh"
        ]
    }
    connection {
        user = var.EC2_USER
        private_key = file(var.PRIV_KEY)
		host = self.private_ip
    }
}
// Sends your public key to the instance
resource "aws_key_pair" "CAL-KEY-PAIR" {
    key_name = "CAL-KEY-PAIR"
    public_key = file(var.PUB_KEY)
}


================================Security Group Creation========================

resource "aws_security_group" "SRRM-VPC-SG" {
    vpc_id = aws_vpc.SRRM-VPC.id
    
    egress {
        from_port = 0
        to_port = 0
        protocol = -1
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        // This means, all ip address are allowed to ssh ! 
        // Do not do it in the production. 
        // Put your office or home address in it!
        cidr_blocks = ["0.0.0.0/0"]
    }
    //If you do not add this rule, you can not reach the NGIX  
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "SRRM-VPC-SG"
    }
}

============================httpd.sh=====================

#!/bin/bash
sudo su
yum ???y install httpd
systemctl start httpd