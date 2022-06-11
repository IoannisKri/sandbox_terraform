resource "aws_cloudwatch_log_group" "myapp" {
  name = "/var/log/messages"

  tags = {
    Environment = "production"
    Application = "myapp"
  }
}

resource "aws_cloudwatch_log_metric_filter" "pagenotfoundmetric" {
  count = var.enable_alarm == "true" ? 1 : 0
  name           = "MyApp404Count"
  pattern        = "\"404 -\""
  log_group_name = element(  split(":", aws_cloudwatch_log_group.myapp.arn), length(  split(":", aws_cloudwatch_log_group.myapp.arn)) - 1)


  metric_transformation {
    name      = "EventCount"
    namespace = "YourNamespace"
    value     = "1"
  }
}

 
resource "aws_cloudwatch_metric_alarm" "foobar" {
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