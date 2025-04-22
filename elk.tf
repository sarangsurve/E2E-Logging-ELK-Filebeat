terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.95.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "3.4.5"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.5.2"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.0.6"
    }
  }
}

provider "aws" {
  #   region     = "ap-south-1"
  #   access_key = "your_aws_access_key"
  #   secret_key = "your_aws_secret_key"
}

resource "tls_private_key" "elk_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "elk_key_pair" {
  key_name   = "elk-key"
  public_key = tls_private_key.elk_key.public_key_openssh
  depends_on = [tls_private_key.elk_key]
}


data "aws_vpc" "main" {
  default = true
}

resource "aws_security_group" "elk_filebeat_sg" {
  name        = "elk-filebeat-sg"
  description = "Managed by Terraform to Allow traffic for ELK & Filebeat"
  vpc_id      = data.aws_vpc.main.id
  depends_on  = [data.aws_vpc.main]
}

resource "aws_vpc_security_group_ingress_rule" "logstash" {
  security_group_id = aws_security_group.elk_filebeat_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 5044
  to_port           = 5044
  description       = "Logstash"
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.elk_filebeat_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  description       = "SSH"
}

resource "aws_vpc_security_group_ingress_rule" "smtp" {
  security_group_id = aws_security_group.elk_filebeat_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 587
  to_port           = 587
  description       = "SMTP"
}

resource "aws_vpc_security_group_ingress_rule" "elasticsearch" {
  security_group_id            = aws_security_group.elk_filebeat_sg.id
  referenced_security_group_id = aws_security_group.elk_filebeat_sg.id
  ip_protocol                  = "tcp"
  from_port                    = 9200
  to_port                      = 9200
  description                  = "Elasticsearch"
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  security_group_id = aws_security_group.elk_filebeat_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "HTTPS"
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.elk_filebeat_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  description       = "HTTP"
}

data "http" "my_ip" {
  url = "https://ipv4.icanhazip.com"
}

resource "aws_vpc_security_group_ingress_rule" "kibana" {
  security_group_id = aws_security_group.elk_filebeat_sg.id
  cidr_ipv4         = "${chomp(data.http.my_ip.response_body)}/32"
  ip_protocol       = "tcp"
  from_port         = 5601
  to_port           = 5601
  description       = "Kibana"
}

resource "aws_vpc_security_group_ingress_rule" "webapp-http" {
  security_group_id = aws_security_group.elk_filebeat_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 8080
  to_port           = 8080
  description       = "HTTP"
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.elk_filebeat_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ELK Instance
resource "aws_instance" "elk" {
  ami                    = "ami-0e35ddab05955cf57"
  instance_type          = "t2.medium"
  key_name               = aws_key_pair.elk_key_pair.key_name
  vpc_security_group_ids = [aws_security_group.elk_filebeat_sg.id]
  user_data              = file("${path.module}/elk_user_data.sh")
  depends_on             = [aws_security_group.elk_filebeat_sg, aws_key_pair.elk_key_pair]
  root_block_device {
    volume_size = 25
    volume_type = "gp3"
  }
  tags = {
    Name = "elk-instance"
  }
}

# App Instance
resource "aws_instance" "app" {
  ami                    = "ami-0e35ddab05955cf57"
  instance_type          = "t2.medium"
  key_name               = aws_key_pair.elk_key_pair.key_name
  vpc_security_group_ids = [aws_security_group.elk_filebeat_sg.id]
  user_data = templatefile("${path.module}/app_user_data.tmpl", {
    ELK_INSTANCE_IP = aws_instance.elk.public_ip
  })
  depends_on = [aws_instance.elk, aws_security_group.elk_filebeat_sg, aws_key_pair.elk_key_pair]
  root_block_device {
    volume_size = 25
    volume_type = "gp3"
  }
  tags = {
    Name = "app-instance"
  }
}

output "elk_instance_public_ip" {
  value = aws_instance.elk.public_ip
}

output "app_instance_public_ip" {
  value = aws_instance.app.public_ip
}

output "private_key" {
  value     = tls_private_key.elk_key.private_key_pem
  sensitive = true
}

resource "local_file" "elk_private_key_file" {
  filename        = "${path.module}/elk-service-keys.pem"
  content         = tls_private_key.elk_key.private_key_pem
  file_permission = "400"
}
