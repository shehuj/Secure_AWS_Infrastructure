resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "Allow SSH + HTTP"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "web" {
  ami           = "ami-0c94855ba95c71c99"
  instance_type = "t3.micro"
  key_name      = var.key_pair
  subnet_id     = element(var.subnet_ids, 0)
  security_groups = [aws_security_group.web.name]

  tags = {
    Name = "web-server"
    Role = "web"
  }
}

output "public_ips" {
  value = aws_instance.web.*.public_ip
}