provider "aws" {
  region = var.aws_region  # o la región correspondiente
}

resource "aws_key_pair" "key" {
  key_name   = "i3-key-g2"
  public_key = file(var.public_key_path)  # Ruta de tu clave pública en tu máquina local
}

resource "aws_instance" "ec2_node" {
  count           = var.instance_count
  #ami             = "ami-091f18e98bc129c4e" # Ubuntu 24 ami londres
  ami             = data.aws_ami.ubuntu_latest.id
  instance_type   = "t3.medium"
  subnet_id       = data.aws_subnets.private_subnets.ids[0]
  key_name        = aws_key_pair.key.key_name
  disable_api_stop = false
  
  # Asignar un rol a la instancia para acceder a ECR
  iam_instance_profile = aws_iam_instance_profile.ec2_role_i3.name
  # Seguridad
  vpc_security_group_ids = [aws_security_group.prometheus.id,data.aws_security_group.default.id]
  root_block_device {
    volume_size = 30  # Tamaño en GB del volumen raíz (aumentado a 50 GB en este ejemplo)
    volume_type = "gp2"  # Tipo de volumen (general purpose SSD)
    delete_on_termination = true  # El volumen raíz se elimina cuando la instancia se termina
  }

  tags = {
    Name = "Grupo2-prometheus-opentelemetry-i3-es-${count.index + 1}",
    Grupo="g2",
    DNS_NAME="i3-rss-engine-demo"
  }

  user_data = templatefile("${path.module}/user_data.tpl", {
    instance_id = "i3-${var.environment}"
    record_name = "i3-${var.environment}-rss-engine-demo.campusdual.mkcampus.com" 
    zone=data.aws_route53_zone.my_hosted_zone.id
    efs_dns_name=data.aws_efs_file_system.elastic_search_efs.dns_name
  })
}
