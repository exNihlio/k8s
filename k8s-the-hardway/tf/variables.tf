variable "region" {
  default = "us-west-2"
}
variable "worker_subnets" {
  default = {
    a = 1 
    b = 2
    c = 3
  }
}
variable "bastion_subnets" {
  default = {
    a = 4
  }
}
variable "k8s_worker_ami" {
  default = "ami-00f0ff8b91cc7c96b"
}

variable "k8s_jump_host_ami" {
  default = "ami-00f0ff8b91cc7c96b"
}

variable "vpc_cidr_block" {
  default = "10.17.0.0/16"
}
