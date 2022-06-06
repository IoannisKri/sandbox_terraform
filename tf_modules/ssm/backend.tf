terraform {
 backend "s3" {
   bucket         = "sysops-soa-co2-willy"
   key            = "ssm"
   region         = "us-east-1"
   dynamodb_table = "terraform-state"
 }
}