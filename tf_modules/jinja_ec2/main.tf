module "security" {
  source = "./security"
  vpc_id = var.vpc_id
}

module "code" {
  source = "./code"
  key = var.key
}

module "ec2_image-1234" {
  depends_on=[module.code,module.security]
  source = "./ec2"
  key = var.key
  name= "image-1234"
  security_group=module.security.security_group
  instance_profile=module.security.instance_profile
  code_object = module.code.code_object
  alb_target_group = module.security.alb_target_group
}

module "ec2_image-4567" {
  depends_on=[module.code,module.security]
  source = "./ec2"
  key = var.key
  name= "image-4567"
  security_group=module.security.security_group
  instance_profile=module.security.instance_profile
  code_object = module.code.code_object
  alb_target_group = module.security.alb_target_group
}



module "elb" {
  source = "./elb"
  aws_lb_target_group_arn = module.security.alb_target_group
  security_group=module.security.security_group
}