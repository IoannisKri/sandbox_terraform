terraform {
  backend "s3" {
    # Replace this with your bucket name!
    bucket         = "ioannis-sysops-soa-co2"
    key            = "global/ssm/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
}
