output "instance_public_ip" {
  value = aws_instance.public_ec2.public_ip
}
output "instance_private_ip" {
  value = aws_instance.public_ec2.private_ip
}

output "sg_id" {
  value = aws_security_group.sg.id  
}