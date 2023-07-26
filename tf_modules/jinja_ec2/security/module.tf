resource "aws_security_group" "allow_tls" {
  name        = "elb"
  description = "Allow TLS inbound traffic"
  #vpc_id      = aws_vpc.main.id
#  SSM will be using port 443 to connect to the instance.
  ingress {
    description      = "443 for ssm"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
#  We will be using port 22 to connect to the instance.
    ingress {
    description      = "22 for me"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
#  We will be using port 5000 to expose the app.
    ingress {
    description      = "5000 for all"
    from_port        = 0
    to_port          = 65535
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }  

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssm"
  }
}


resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "ec2_elb"
  role = aws_iam_role.role.name
}

resource "aws_iam_role" "role" {
  name = "ec2_elb"
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

data "aws_iam_policy" "AmazonS3FullAccess" {
  name = "AmazonS3FullAccess"
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

resource "aws_iam_role_policy_attachment" "AmazonS3FullAccess" {
  role       = aws_iam_role.role.name
  policy_arn = data.aws_iam_policy.AmazonS3FullAccess.arn
}


resource "aws_lb_target_group" "ip-example" {
  name        = "tf-example-lb-tg"
  port        = 5000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id
}

output "security_group" {
  value =  aws_security_group.allow_tls.id

}

output "instance_profile" {
  value =  aws_iam_instance_profile.ec2_ssm_profile.id
}

output "alb_target_group" {
  value = aws_lb_target_group.ip-example.arn
}
