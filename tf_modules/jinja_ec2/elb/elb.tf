#This data provider helps us get some context information (e.g. account id)
data "aws_caller_identity" "current" {}

#Get existing subnets
#We will provide the subnet references to the load balancer
data "aws_subnet_ids" "example" {
  vpc_id = var.vpc_id
}

resource "aws_s3_bucket" "elb_logs" {
#  Create a simple bucket to store ELB logs  
    bucket = "sysops-soa-co2-elb-logs-${var.name}"
}

resource "aws_s3_bucket" "athena_logs" {
#  Create a simple bucket to store Athena query result logs  
    bucket = "sysops-soa-co2-athena-logs-${var.name}"
}

resource "aws_s3_bucket_policy" "allow_access_from_another_account" {
  #Put bucket policy to allow ELB to write logs to bucket
  bucket = aws_s3_bucket.elb_logs.id
  policy = data.aws_iam_policy_document.allow_access.json
}

data "aws_iam_policy_document" "allow_access" {
  #Bucket policy needs to allow the current account to write files to bucket
  statement {
    principals {
      type        = "AWS"
      #This is intentionally hardcoded since it has to be the ELB region ID
      #More details here https://docs.aws.amazon.com/elasticloadbalancing/latest/classic/enable-access-logs.html
      identifiers = [ "arn:aws:iam::127311923021:root"  ]
    }
    actions = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.elb_logs.arn}/*" ]
  }
}


resource "aws_lb" "front_end" {
  #The load balancer spans over all subnets
  name               = var.name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.security_group]
  subnets            = data.aws_subnet_ids.example.ids
  enable_deletion_protection = true
  #Access logs are enabled
  access_logs {
    bucket  = aws_s3_bucket.elb_logs.bucket
    prefix  = "test-lb"
    enabled = true
  }

  tags = {
    Environment = "dev"
  }
}

resource "aws_lb_listener" "front_end" {
  #We need a listener between the load balancer and the target group
  load_balancer_arn = aws_lb.front_end.arn
  port              = "5000"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = var.aws_lb_target_group_arn
  }
}

resource "aws_glue_catalog_database" "aws_glue_catalog_database" {
  #Create an athena database to store the elb logs table
  name = "logs"
}

resource "aws_glue_catalog_table" "aws_glue_catalog_table" {
  #This table will allow us to query ALB logs stored in s3
  #The logs will be parsed and each attribute gets into a seperate column 
  name          = "parsed_elb_logs"
  database_name = element(split(":", aws_glue_catalog_database.aws_glue_catalog_database.id), length(split(":", aws_glue_catalog_database.aws_glue_catalog_database.id)) - 1)
  table_type = "EXTERNAL_TABLE"

  parameters = {
    EXTERNAL              = "TRUE"
  }

  storage_descriptor {
    location      = "s3://sysops-soa-co2-elb-logs-${var.name}/test-lb/AWSLogs/${data.aws_caller_identity.current.id}/elasticloadbalancing"
    input_format  =   "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.serde2.OpenCSVSerde"

      parameters = {
        "separatorChar" = " "
        "quoteChar" = "\""
        "escapeChar"="\\", 

      }
    }
    columns {
      name = "type"
      type = "string"
    }
    columns {
      name = "time"
      type = "string"
    }
    columns {
      name = "elb"
      type = "string"
    }
    columns {
      name = "client_port"
      type = "string"
    }
    columns {
      name = "target_port"
      type = "string"
    }
    columns {
      name = "request_processing_time"
      type = "float"
    }    
    columns {
      name = "target_processing_time"
      type = "float"
    }    
    columns {
      name = "response_processing_time"
      type = "float"
    }        
    columns {
      name = "elb_status_code"
      type = "string"
    }        
    columns {
      name = "target_status_code"
      type = "string"
    } 
    columns {
      name = "received_bytes"
      type = "string"
    }     
    columns {
      name = "sent_bytes"
      type = "string"
    }       
    columns {
      name = "request"
      type = "string"
    }   
    columns {
      name = "user_agent"
      type = "string"
    } 
    columns {
      name = "ssl_cipher"
      type = "string"
    } 
    columns {
      name = "ssl_protocol"
      type = "string"
    } 
    columns {
      name = "target_group_arn"
      type = "string"
    } 
    columns {
      name = "trace_id"
      type = "string"
    } 
    columns {
      name = "domain_name"
      type = "string"
    } 
    columns {
      name = "chosen_cert_arn"
      type = "string"
    } 
    columns {
      name = "matched_rule_priority"
      type = "string"
    } 
    columns {
      name = "request_creation_time"
      type = "string"
    } 
    columns {
      name = "actions_executed"
      type = "string"
    } 
    columns {
      name = "redirect_url"
      type = "string"
    }     
    columns {
      name = "error_reason"
      type = "string"
    }         
    columns {
      name = "target_port_list"
      type = "string"
    }      
    columns {
      name = "target_status_code_list"
      type = "string"
    }          
    columns {
      name = "classification"
      type = "string"
    }
    columns {
      name = "classification_reason"
      type = "string"
    }

}
}

#We need an Athena workgroup in order to execute athena queries
resource "aws_athena_workgroup" "example" {
  name = "example"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true
    #Specify where the query results are written
    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_logs.id}/output/"
    }
  }
}