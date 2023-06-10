terraform {
  backend "s3" {
	bucket = "jn-webapp-tf"
	key	= "prod/eks.tfstate"
	region = "us-east-1"
  }
}