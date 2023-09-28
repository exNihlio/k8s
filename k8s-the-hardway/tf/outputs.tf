output "bastion_ip" {
  value = aws_instance.this_bastion.public_ip
}

output "worker_hosts" {
  value = [for record in aws_route53_record.this_worker : record.fqdn ]
}

output "controller_hosts" {
  value = [for record in aws_route53_record.this_controller : record.fqdn ]
}
