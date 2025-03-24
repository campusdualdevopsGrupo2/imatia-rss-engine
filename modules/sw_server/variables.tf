variable "aws_region" {
  description = "AWS region"
  type=string
  #default = "eu-west-3"

}

variable "ami_id" {
  description = "The AMI ID to use for the EC2 instance"
  type        = string
  default     = "ami-06e02ae7bdac6b938" 
}


variable "private_key_path" {
  description = "Ruta al archivo de la clave privada SSH para acceder a las instancias EC2."
  type        = string
  #default = "../../my-ec2-key"
}

variable "public_key_path" {
  description = "Ruta al archivo de la clave pública SSH asociada a la clave privada para acceder a las instancias EC2."
  type        = string
  #default = "../../my-ec2-key.pub"
}


variable "vpc_id" {
  type        = string
  description = "ID de la VPC"
  #default = "vpc-01c097d1d9b73fc50"
}

variable "environment" {
  type        = string
  description = "Ambiente (dev/prod)"
  #default     = "dev"
}