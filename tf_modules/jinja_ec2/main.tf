locals {
  initial_deployment = "true"
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
amazon-linux-extras install java-openjdk11
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
aws s3 cp  ${local.kafka_s3_path} /etc/init.d/kafka
chmod +x /etc/init.d/kafka
chown root:root /etc/init.d/kafka
chkconfig --add kafka
mkdir -p /data/kafka
chown -R ec2-user:ec2-user /data/kafka
rm config/server.properties
aws s3 cp s3://${aws_s3_bucket.source_code.id}/server.properties-1 config/server.properties
aws s3 cp s3://${aws_s3_bucket.source_code.id}/etc_hosts /etc/hosts
mkdir -p /data/zookeeper
chown -R ec2-user:ec2-user /data/zookeeper
echo "1" > /data/zookeeper/myid
aws s3 cp s3://${aws_s3_bucket.source_code.id}/${aws_s3_bucket_object.zookeeper_properties.id} /home/ec2-user/kafka/config/zookeeper.properties
service zookeeper start 
service kafka start
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
amazon-linux-extras install java-openjdk11
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
aws s3 cp  ${local.kafka_s3_path} /etc/init.d/kafka
chmod +x /etc/init.d/kafka
chown root:root /etc/init.d/kafka
chkconfig --add kafka
mkdir -p /data/kafka
chown -R ec2-user:ec2-user /data/kafka
rm config/server.properties
aws s3 cp s3://${aws_s3_bucket.source_code.id}/server.properties-2 config/server.properties
aws s3 cp s3://${aws_s3_bucket.source_code.id}/etc_hosts /etc/hosts
mkdir -p /data/zookeeper
chown -R ec2-user:ec2-user /data/zookeeper
echo "2" > /data/zookeeper/myid
aws s3 cp s3://${aws_s3_bucket.source_code.id}/${aws_s3_bucket_object.zookeeper_properties.id} /home/ec2-user/kafka/config/zookeeper.properties
service zookeeper start 
service kafka start
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
  user_data = local.initial_deployment =="true" ? "" : local.user_data_1
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
  user_data = local.initial_deployment =="true" ? "" : local.user_data_2
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

resource "aws_s3_bucket_object" "zookeeper_properties" {
  bucket         = aws_s3_bucket.source_code.id
  key            = "zookeeper.properties"
  content_base64 = base64encode(file("zookeeper.properties"))
}
resource "aws_s3_bucket_object" "kafka" {
  bucket         = aws_s3_bucket.source_code.id
  key            = "kafka"
  content_base64 = base64encode(file("kafka"))
}

resource "random_id" "server" {
  byte_length = 8
}


resource "null_resource" "concatenate_etc_hosts" {
depends_on = [module.ec2_image-1,module.ec2_image-2]
triggers = {
    cluster_instance_ids = random_id.server.hex
  }  #TODO add line breaks
  provisioner "local-exec" {
    working_dir = "etc_hosts"
    command = <<EOF
      aws s3 cp s3://${aws_s3_bucket.source_code.id}/etc-hosts-1 .
      aws s3 cp s3://${aws_s3_bucket.source_code.id}/etc-hosts-2 .
      cat * > my_temp_file
      aws s3 cp my_temp_file s3://${aws_s3_bucket.source_code.id}/etc_hosts
EOF
  }
}