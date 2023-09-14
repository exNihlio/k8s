terraform  {
  backend "s3" {
    bucket = "cab-tfstate-bucket-s3-azvaq1"
    key = "k8s-tfstate"
    region = "us-west-2"
  }
}
