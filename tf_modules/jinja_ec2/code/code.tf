resource "aws_s3_bucket_object" "object" {
  bucket = "sysops-soa-co2-${var.key}" 
  key    = "app.py"
  source = "code/app.py"
}



output "code_object" {
  value =  aws_s3_bucket_object.object.key
} 



