resource "aws_s3_bucket" "ssm_output" {
#  Create a simple bucket to store SSM logs  
    bucket = var.bucket_name
}

resource "random_id" "random" {
#  Create a random id that is used to trick terraform into running the ssm command each time  
    keepers = {
    # Generate a new id each time
    dummy = timestamp()
  }
  byte_length = 8
}

resource "null_resource" "put-ssm-parameter" {
#  Create an SSM parameter that contains the logagent config which will be used in the EC2 images  
#  Recreate only when the input config changes. The overwrite flag is also set in the command. 
  triggers = {
    sha1 = "${sha1(file("cwagent.json"))}"
  }
  provisioner "local-exec" {
    command = "aws ssm put-parameter --name \"cloudwatch_agent\" --type \"String\" --value file://cwagent.json --overwrite  --region us-east-1"
  }
}

resource "null_resource" "run-ssm-command" {
#  Install, configure and start Cloudwatch Logagent in EC2 instances with a specific tag  
  depends_on=[aws_s3_bucket.ssm_output,random_id.random,null_resource.put-ssm-parameter]
#  Always recreate (run the ssm command) with this dirty hack.
   lifecycle {
    replace_triggered_by = [
      random_id.random
    ]
  }
  provisioner "local-exec" {
#  Some cool \\\ escape happened here. However there is no need to get ssm parameter since the same thing happens when starting the agent     
#  command = "aws ssm send-command --parameters '{\"commands\":[ \"#!/bin/bash\",  \"sudo yum update -y\",  \"sudo yum install -y amazon-cloudwatch-agent\",\"sudo aws ssm get-parameter --name cloudwatch_agent --region us-east-1 | jq \\\".Parameter.Value | fromjson\\\" >> /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json\",\"sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c ssm:cloudwatch_agent\", \"sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -m ec2 -a status\"]}' --document-name \"AWS-RunShellScript\"  --targets '[{\"Key\":\"tag:SSM\",\"Values\":[\"TRUE\"]}]'  --timeout-seconds 600 --max-concurrency \"50\" --max-errors \"0\" --output-s3-bucket-name \"${aws_s3_bucket.ssm_output.id}\" --output-s3-key-prefix \"ssm_outputs\" --cloud-watch-output-config '{\"CloudWatchOutputEnabled\":true}' --region us-east-1"
    command = "aws ssm send-command --parameters '{\"commands\":[ \"#!/bin/bash\",  \"sudo yum update -y\",  \"sudo yum install -y amazon-cloudwatch-agent\",\"sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c ssm:cloudwatch_agent\", \"sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -m ec2 -a status\"]}' --document-name \"AWS-RunShellScript\"  --targets '[{\"Key\":\"tag:SSM\",\"Values\":[\"TRUE\"]}]'  --timeout-seconds 600 --max-concurrency \"50\" --max-errors \"0\" --output-s3-bucket-name \"${aws_s3_bucket.ssm_output.id}\" --output-s3-key-prefix \"ssm_outputs\" --cloud-watch-output-config '{\"CloudWatchOutputEnabled\":true}' --region us-east-1"
  }
}