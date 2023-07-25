locals {
  zookeper_s3_path = "s3://${aws_s3_bucket.source_code.id}/${aws_s3_bucket_object.zookeeper.id}"
  kafka_s3_path = "s3://${aws_s3_bucket.source_code.id}/${aws_s3_bucket_object.kafka.id}"
  user_data_1 = <<EOF
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

aws s3 cp  ${local.zookeper_s3_path} /etc/init.d/zookeeper
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

aws s3 cp  ${local.kafka_s3_path} /etc/init.d/kafka

chmod +x /etc/init.d/kafka

chown root:root /etc/init.d/kafka

sudo update-rc.d kafka defaults

sudo service kafka start
Stop the kafka and zookeeper Services on Each Server
sudo service zookeeper stop

sudo service kafka stop
Create the logs Directory for the Kafka Service
sudo mkdir -p /data/kafka

sudo chown -R ec2-user:ec2-user /data/kafka
Create the server.properties File
rm config/server.properties

vim config/server.properties

aws s3 cp s3://${ws_s3_bucket.source_code.id}/server.properties-1 /etc/init.d/kafka
EOF
  user_data_2 = <<EOF
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

aws s3 cp  ${local.zookeper_s3_path} /etc/init.d/zookeeper
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

aws s3 cp  ${local.kafka_s3_path} /etc/init.d/kafka

aws s3 cp s3://${ws_s3_bucket.source_code.id}/server.properties-2 /etc/init.d/kafka
EOF
}


module "security" {
  source = "./security"
  vpc_id = var.vpc_id
}

module "code" {
  source = "./code"
  key = var.key
}

module "ec2_image-1" {
  depends_on=[module.code,module.security]
  source = "./kafka_ec2"
  key = var.key
  name= "1"
  id = "1"
  security_group=module.security.security_group
  instance_profile=module.security.instance_profile
  code_object = module.code.code_object
  alb_target_group = module.security.alb_target_group
  zookeper_s3_path = local.zookeper_s3_path
  kafka_s3_path = local.kafka_s3_path
  user_data = var.user_data
  source_code_bucket = aws_s3_bucket.source_code.id

}


module "ec2_image-2" {
  depends_on=[module.code,module.security]
  source = "./kafka_ec2"
  key = var.key
  name= "2"
  id = "2"
  security_group=module.security.security_group
  instance_profile=module.security.instance_profile
  code_object = module.code.code_object
  alb_target_group = module.security.alb_target_group
  zookeper_s3_path = local.zookeper_s3_path
  kafka_s3_path = local.kafka_s3_path
  user_data = var.user_data
  source_code_bucket = aws_s3_bucket.source_code.id
}


resource "aws_s3_bucket" "source_code" {
#  Create a simple bucket to store Athena query result logs  
    bucket = "sysops-ccdk-${var.vpc_id}"
}
#module "elb" {
#  source = "./elb"
#  aws_lb_target_group_arn = module.security.alb_target_group
#  security_group=module.security.security_group
#  name = var.key
#  vpc_id =var.vpc_id
#}

resource "aws_s3_bucket_object" "zookeeper" {
  bucket         = aws_s3_bucket.source_code.id
  key            = "zookeeper"
  content_base64 = base64encode(file("zookeeper"))
}

resource "aws_s3_bucket_object" "kafka" {
  bucket         = aws_s3_bucket.source_code.id
  key            = "kafka"
  content_base64 = base64encode(file("kafka"))
}
