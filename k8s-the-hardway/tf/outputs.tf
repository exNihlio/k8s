output "bastion_ip" {
  value = aws_instance.this_bastion.public_ip
}
