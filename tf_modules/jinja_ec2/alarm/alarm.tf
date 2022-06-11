resource "aws_cloudwatch_log_group" "myapp" {
  #The cloudwatch group would be created automatically. 
  #We choose to create it here so that retention can be imposed
  name = "/var/log/messages"
  retention_in_days = 7
  tags = {
    Environment = "production"
    Application = "myapp"
  }
}

resource "aws_cloudwatch_log_metric_filter" "pagenotfoundmetric" {
  #Create resource based on conditional
  count = var.enable_alarm == "true" ? 1 : 0
  name           = "MyApp404Count"
  pattern        = "\"404 -\"" #Simple pattern that detects 404 errors
  #Terraform expression that splits string and takes the last item of the resulting list
  log_group_name = element(split(":", aws_cloudwatch_log_group.myapp.arn), length(split(":", aws_cloudwatch_log_group.myapp.arn)) - 1)
  metric_transformation {
    name      = "EventCount"
    namespace = "YourNamespace"
    value     = "1"
  }
}

 
resource "aws_cloudwatch_metric_alarm" "pagenotfoundmetricalarm" {
  #Create resource based on conditional
  count = var.enable_alarm == "true" ? 1 : 0
  alarm_name                = "MyApp404Count"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = "1"
  metric_name               = "EventCount"
  namespace                 = "YourNamespace"
  period                    = "10"
  statistic                 = "Sum"
  threshold                 = "0"
  alarm_description         = "This metric monitors 404 errors"
  insufficient_data_actions = []
  treat_missing_data        = "notBreaching"
  }