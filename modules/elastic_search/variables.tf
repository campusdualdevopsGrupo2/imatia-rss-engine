variable "aws_region" {
  type        = string
  description = "Región de AWS"
  #default     = "eu-west-2"
}


# ID de la VPC (para la consulta de seguridad)
variable "vpc_id" {
  description = "ID de la VPC donde se encuentran las instancias"
  type        = string
  #default     = "vpc-01c097d1d9b73fc50"  # Reemplaza con el ID de tu VPC
}
variable "subnet_ids" {
  type        = list(string)
  description = "IDs de las subnets privadas"

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

# ID de la AMI (Imagen de la máquina virtual)
variable "ami_id" {
  description = "ID de la imagen de la máquina virtual"
  type        = string
  default     = "ami-06e02ae7bdac6b938"  # Reemplaza con el ID de tu AMI
}


variable "environment"{
    type= string
    #default= "demo"
}
variable "amount"{
  type=number
  default=3
}

variable "sg_sw_worker"{
    type= string
}
variable "hosted_zone_arn" {
  type        = string
  description = "route53 hostez zone arn"

}
variable "hosted_zone_id" {
  type        = string
  description = "route53 hostez zone arn"

}
variable "aws_secret_arn" {
  type        = string
  description = "arn from secret"

}


variable "num_availability_zones" {
  type        = number

}

variable "efs_dns_name"{
  type=string
}

variable "sg_default_id"{
  type=string
}

variable "sg_grafana"{
    type= string
}
variable "sg_otel"{
    type= string
}
variable "aws_key_name"{
  type = string
}
variable "secret_name"{
  type=string
}