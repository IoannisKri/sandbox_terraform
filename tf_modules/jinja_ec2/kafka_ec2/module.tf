locals {
  user_data_initial= <<EOF
#!/bin/bash
cd home/ec2-user
# download the binaries
wget https://archive.apache.org/dist/kafka/2.2.0/kafka_2.12-2.2.0.tgz

# unpack the tarball
tar -xvf kafka_2.12-2.2.0.tgz

# rename dir to kafka
mv kafka_2.12-2.2.0 kafka

# change dir into kafka
cd kafka

# install java
yum install -y java

# verify java version
java -version

# disable RAM swap
swapoff -a

# remove swap from fstab
sed -i '/ swap / s/^/#/' /etc/fstab

aws s3 cp  ${var.zookeper_s3_path} /etc/init.d/zookeeper
# change file permission
chmod +x /etc/init.d/zookeeper

# change ownership to root
chown root:root /etc/init.d/zookeeper

# install init script
chkconfig --add zookeeper

# start the zookeeper service
service zookeeper start

# verify the service is up
service zookeeper status

EOF  






}

resource "aws_instance" "kafka" {
#  Create some EC2 instances where we are allowed to connect via SSH.
  ami = "ami-0022f774911c1d690"
  key_name = var.key
  user_data_replace_on_change = true
  vpc_security_group_ids = [ var.security_group ]
  iam_instance_profile= var.instance_profile
  instance_type = "t3.micro"
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

