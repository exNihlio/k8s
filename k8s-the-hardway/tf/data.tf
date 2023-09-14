data "aws_ami" "opensuse_leap15_arm64" {
  most_recent = true
  filter {
    name = "name"
    values = ["openSUSE-Leap-15-*"]
  }
  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name = "architecture"
    values = ["arm64"]
  }
  owners = ["679593333241"]
}
