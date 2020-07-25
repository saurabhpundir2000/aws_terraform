
resource "tls_private_key" "mykey" {
  algorithm = "RSA"
}

resource "aws_key_pair" "keypair1" {
  key_name   = "mykey"
  public_key = "${tls_private_key.mykey.public_key_openssh}"


  depends_on = [
    tls_private_key.mykey
  ]
}

resource "local_file" "key-file" {
  content  = "${tls_private_key.mykey.private_key_pem}"
  filename = "mykey.pem"


  depends_on = [
    tls_private_key.mykey
  ]
}



data "template_file" "phpconfig" {
  template = file("files/conf.wp-config.php")

  vars = {
    db_port = aws_db_instance.mysql.port
    db_host = aws_db_instance.mysql.address
    db_user = var.username
    db_pass = var.password
    db_name = var.dbname
  }
}

resource "aws_db_instance" "mysql" {
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = "db.t2.micro"
  name                   = var.dbname
  username               = var.username
  password               = var.password
  parameter_group_name   = "default.mysql5.7"
  vpc_security_group_ids = [aws_security_group.mysql.id]
  db_subnet_group_name   = aws_db_subnet_group.mysql.name
  skip_final_snapshot    = true
}

resource "aws_instance" "ec2" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  depends_on = [
    aws_db_instance.mysql,
  ]

  key_name                    = aws_key_pair.keypair1.key_name
  vpc_security_group_ids      = [aws_security_group.web.id]
  subnet_id                   = aws_subnet.public1.id
  associate_public_ip_address = true

  user_data = file("files/userdata.sh")

  tags = {
    Name = "EC2 Instance"
  }

  provisioner "file" {
    source      = "files/userdata.sh"
    destination = "/var/tmp/userdata.sh"
  
    connection {
      type        = "ssh"
      user        = "ubuntu"
      host = self.public_ip
      private_key = file("mykey.pem")
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /var/tmp/userdata.sh",
      "sh /var/tmp/userdata.sh",
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      host = self.public_ip
      private_key = file("mykey.pem")
    }
  }

  provisioner "file" {
    content     = data.template_file.phpconfig.rendered
    destination = "/var/tmp/wp-config.php"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      host = self.public_ip
      private_key = file("mykey.pem")
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo cp /var/tmp/wp-config.php /var/www/html/wp-config.php",
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      host = self.public_ip
      private_key = file("mykey.pem")
    }
  }

  timeouts {
    create = "20m"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-trusty-14.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}
