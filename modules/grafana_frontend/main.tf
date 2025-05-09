

resource "aws_instance" "public_ec2" {
  ami           = var.ami_id
  instance_type = "t3.medium"
  key_name      = var.aws_key_name
  # subnet_id       = var.subnet_ids
  subnet_id       = var.subnet_ids[0]
  disable_api_stop = false

  tags = {
    Name = "I4_instance-${var.environment}",
    Grupo= "g2"

  }
  iam_instance_profile = aws_iam_instance_profile.ec2_role_i4.name

  # Crear un grupo de seguridad para permitir el acceso SSH
  vpc_security_group_ids = [aws_security_group.sg.id,var.sg_default_id]

  associate_public_ip_address = true

  user_data = templatefile("${path.module}/user_data.tpl", {
    inumber = "i4"
    record_name= "i4-${var.environment}-rss-engine-demo.campusdual.mkcampus.com"
    zone = var.hosted_zone_id
    efs_dns_name=var.efs_id
    environment=var.environment
    secret_name=var.secret_name
  })

  depends_on = [aws_security_group.sg]
}