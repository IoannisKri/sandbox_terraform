locals {
  user_data_initial= <<EOF
#!/bin/bash
rm /var/lib/cloud/instances/*/sem/config_scripts_user
EOF
}

resource "aws_instance" "kafka" {
#  Create some EC2 instances where we are allowed to connect via SSH.
  ami = "ami-0022f774911c1d690"
  key_name = var.key
  user_data_replace_on_change = false
  vpc_security_group_ids = [ var.security_group ]
  iam_instance_profile= var.instance_profile
  instance_type = "t2.medium"
#  The SSM agent is preinstalled. Without it, SSM will not be able to execute the necessary actions.
  user_data = var.user_data == "" ? local.user_data_initial : var.user_data



#  The instances are tagged with SSM = TRUE because ssm will use this tag to select them and execute some commands
  tags = {
    SSM = "TRUE"
    Name = var.name
  }
}

#Each instance gets its own Elastic IP
resource "aws_eip" "lb" {
  instance = aws_instance.kafka.id
  vpc      = true
}

#Each instance is assigned to the lb group upon creation
resource "aws_lb_target_group_attachment" "test" {
  target_group_arn = var.alb_target_group
  target_id        = aws_eip.lb.private_ip
  port             = 5000
}


data "template_file" "server_properties" {
  template = "${file("${path.cwd}/server.properties.tpl")}"

  vars = {
    ip = aws_eip.lb.public_ip
    id = var.id
  }
}

resource "aws_s3_bucket_object" "server_properties" {

  bucket = var.source_code_bucket
  key = "server.properties-${var.id}"
  content = data.template_file.server_properties.rendered
}

data "template_file" "etc_hosts" {
  template = "${file("${path.cwd}/etc_hosts.tpl")}"

  vars = {
    ip = aws_eip.lb.public_ip
    id = var.id
  }
}


resource "aws_s3_bucket_object" "etc_hosts" {
  # Create an etc_hosts file per instance. These files are then concatenated into a single final etc_hosts file
  etag   = filemd5("${path.cwd}/etc_hosts.tpl")
  bucket = var.source_code_bucket
  key = "etc-hosts-${var.id}"
  content = data.template_file.etc_hosts.rendered
}

