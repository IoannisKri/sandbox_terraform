terraform {
 backend "s3" {
   bucket         = "<BUCKET_NAME>"
   key            = "<KEY_NAME>"
   region         = "us-east-1"
   dynamodb_table = "terraform-state"
 }
}