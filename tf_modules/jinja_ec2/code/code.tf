#Create app.py as an s3 object which will be downloaded by the image as an "artifact"
resource "aws_s3_bucket_object" "object" {
  bucket = "sysops-soa-co2-${var.key}" 
  key    = "app.py"
  source = "code/app.py"
}

#Use outputs so that values can be shared between submodules
output "code_object" {
  value =  aws_s3_bucket_object.object.key
} 



