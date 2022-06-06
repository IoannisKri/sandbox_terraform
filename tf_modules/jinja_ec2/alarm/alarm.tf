resource "aws_cloudwatch_log_metric_filter" "pagenotfoundmetric" {
  name           = "MyApp404Count"
  pattern        = "\"404 -\""
  log_group_name = "/var/log/messages"

  metric_transformation {
    name      = "EventCount"
    namespace = "YourNamespace"
    value     = "1"
  }
}

 
resource "aws_cloudwatch_metric_alarm" "foobar" {
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