resource "time_sleep" "wait_30_seconds" {
  depends_on = [aws_security_group.web_sg, aws_key_pair.generated_key]
  create_duration = "30s"
}

provider "aws" {
  region = var.aws_region
}

resource "aws_security_group" "web_sg" {
  name        = "phase2-web-sg-cloud"
  description = "Allow SSH, Web, and Traefik Dashboard"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Traefik Dashboard"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "phase2-key-cloud"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.module}/../ansible/key.pem"
  file_permission = "0600"
}

resource "aws_instance" "app_server" {
  depends_on = [time_sleep.wait_30_seconds]  
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = aws_key_pair.generated_key.key_name
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # Ensure the disk is large enough for monitoring logs
  root_block_device {
    volume_size = 20
  }

  tags = {
    Name = "Phase2-Server"
  }
}

resource "aws_eip" "static_ip" {
  instance = aws_instance.app_server.id
  domain   = "vpc"
}

resource "local_file" "ansible_inventory" {
  content  = <<EOT
[webserver]
${aws_eip.static_ip.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=${abspath(local_file.private_key.filename)}
EOT
  filename = "${path.module}/../ansible/inventory.ini"
}

resource "null_resource" "run_ansible" {
  depends_on = [
    aws_eip.static_ip,
    local_file.ansible_inventory,
    local_file.private_key
  ]

  provisioner "remote-exec" {
    inline = ["echo 'Server is up!'"]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.ssh_key.private_key_pem
      host        = aws_eip.static_ip.public_ip
    }
  }

  provisioner "local-exec" {
    command = <<EOT
      export ANSIBLE_HOST_KEY_CHECKING=False
      ansible-playbook -i ${local_file.ansible_inventory.filename} ${path.module}/../ansible/playbook.yml -e "grafana_cloud_token=${var.grafana_cloud_token}"
    EOT
  }
}