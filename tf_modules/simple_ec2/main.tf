resource "aws_instance" "web" {
#  Create some EC2 instances where we are allowed to connect via SSH.
  for_each = toset(var.instances)
  ami = "ami-0022f774911c1d690"
  key_name = "ioannis"
  vpc_security_group_ids = [
    aws_security_group.allow_tls.id
  ]
  iam_instance_profile=aws_iam_instance_profile.ec2_ssm_profile.id
  instance_type = "t3.micro"
#  The SSM agent is preinstalled. Without it, SSM will not be able to execute the necessary actions.
  user_data = <<EOF
#!/bin/bash
sudo yum install -y jq
sudo yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
sudo systemctl start amazon-ssm-agent
EOF  
#  The instances are tagged with SSM = TRUE because ssm will use this tag to select them and execute some commands
  tags = {
    SSM = "TRUE"
    Name = each.value
  }
}

resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  #vpc_id      = aws_vpc.main.id
#  SSM will be using port 443 to connect to the instance.
  ingress {
    description      = "443 for ssm"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["0.0.0.0/0"]
  }
#  We will be using port 22 to connect to the instance.
    ingress {
    description      = "22 for me"
    from_port        = 22
    to_port          = 22
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


resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "ec2_ssm_profile"
  role = aws_iam_role.role.name
}

resource "aws_iam_role" "role" {
  name = "ec2_allow_ssm"
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

data "aws_iam_policy" "CloudWatchFullAccess" {
  name = "CloudWatchFullAccess"
}

data "aws_iam_policy" "AmazonSSMManagedInstanceCore" {
  name = "AmazonSSMManagedInstanceCore"
}

#The instance should eventually be able to write logs to Cloudwatch. This policy is good enough
resource "aws_iam_role_policy_attachment" "CloudWatchFullAccess" {
  role       = aws_iam_role.role.name
  policy_arn = data.aws_iam_policy.CloudWatchFullAccess.arn
}

#The instance should eventually be able to communicate with SSM. This policy is good enough
resource "aws_iam_role_policy_attachment" "AmazonSSMManagedInstanceCore" {
  role       = aws_iam_role.role.name
  policy_arn = data.aws_iam_policy.AmazonSSMManagedInstanceCore.arn
}