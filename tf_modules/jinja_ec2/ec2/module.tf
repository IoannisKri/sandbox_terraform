
resource "aws_instance" "web" {
#  Create some EC2 instances where we are allowed to connect via SSH.
  ami = "ami-0022f774911c1d690"
  key_name = var.key
  user_data_replace_on_change = true
  vpc_security_group_ids = [ var.security_group ]
  iam_instance_profile= var.instance_profile
  instance_type = "t3.micro"
#  The SSM agent is preinstalled. Without it, SSM will not be able to execute the necessary actions.
  user_data = <<EOF
#!/bin/bash
yum install -y jq
yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
systemctl start amazon-ssm-agent
pip3 install flask jinja2
cd home/ec2-user
mkdir app
cd app
aws s3 cp  s3://sysops-soa-co2-${var.key}/${var.code_object} .
flask run -h 0.0.0.0 -p 5000
EOF  
#  The instances are tagged with SSM = TRUE because ssm will use this tag to select them and execute some commands
  tags = {
    SSM = "TRUE"
    Name = var.name
  }
}

resource "aws_eip" "lb" {
  instance = aws_instance.web.id
  vpc      = true
}

resource "aws_lb_target_group_attachment" "test" {
  target_group_arn = var.alb_target_group
  target_id        = aws_eip.lb.private_ip
  port             = 5000
}