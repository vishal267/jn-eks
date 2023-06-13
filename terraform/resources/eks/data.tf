data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "jn-webapp-tf"
    key    = "prod/vpc.tfstate"
    region = "us-east-1"
  }
}
