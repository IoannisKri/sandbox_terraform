output "public_ip" {
  value = aws_instance.kafka[*].public_ip
}

output "server_properties_id" {
    value = aws_s3_bucket_object.server_properties.id
}