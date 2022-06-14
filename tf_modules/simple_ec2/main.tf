resource "aws_s3_bucket_object" "object" {
  #Put the webapp code in an s3 bucket as if it was an artifact.
  #Then it will be downloaded by the instance, executed and exposed
  bucket = "sysops-soa-co2-${var.key}" 
  key    = "app.py"
  source = "app.py"
}

resource "aws_instance" "web" {
  #Create some EC2 instances where we are allowed to connect via SSH.
  ami = "ami-0022f774911c1d690"
  key_name = var.key
  user_data_replace_on_change = true
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]
  iam_instance_profile=aws_iam_instance_profile.ec2_ssm_profile.id
  instance_type = "t3.micro"
 #No sudo is needed when using user data commands
  user_data = <<EOF
#!/bin/bash
yum install -y jq
pip3 install flask
cd home/ec2-user
mkdir app
cd app
aws s3 cp  s3://sysops-soa-co2-${var.key}/${aws_s3_bucket_object.object.key} .
flask run -h 0.0.0.0 -p 5000
EOF  
#  The instances are tagged with SSM = TRUE because ssm will use this tag to select them and execute some commands
  tags = {
    SSM = "TRUE"
    Name = each.value
  }
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow TLS inbound traffic"
#  We will be using port 22 to connect to the instance.
    ingress {
    description      = "22 for me"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["0.0.0.0/0"]
  }
#  We will be using port 5000 to expose the app.
    ingress {
    description      = "5000 for all"
    from_port        = 5000
    to_port          = 5000
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["0.0.0.0/0"]
  }  

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_ssm"
  }
}

resource "aws_iam_instance_profile" "ec2_simple_profile" {
  name = "ec2_simple_profile"
  role = aws_iam_role.role.name
}

#The role needs EC2 as principal
resource "aws_iam_role" "role" {
  name = "ec2_simple"
  path = "/"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

#Reference existing IAM policy with data
data "aws_iam_policy" "AmazonS3FullAccess" {
  name = "AmazonS3FullAccess"
}

#The instance should be able to download the webapp code from s3. This policy is very wide but good enough
resource "aws_iam_role_policy_attachment" "AmazonS3FullAccess" {
  role       = aws_iam_role.role.name
  policy_arn = data.aws_iam_policy.AmazonS3FullAccess.arn
}