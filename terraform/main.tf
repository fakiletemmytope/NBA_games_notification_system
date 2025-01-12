variable "region" {
  type        = string
  default     = "us-east-1"
  description = "aws region variable"
}

variable "id" {
  type        = number
  default     = #AWS USER ID
  description = "aws user id"
}

# a simple notification service topic
resource "aws_sns_topic" "gd_notification" {
  name = "gd_notification"
}


# topic subscriber
resource "aws_sns_topic_subscription" "subscribed_user" {
  topic_arn = aws_sns_topic.gd_notification.arn
  protocol  = "email"
  endpoint  = #Subscriber's Email 
}

# a custom Iam_policy
resource "aws_iam_policy" "gd_notification_policy" {
  name = "gd_notification_policy"
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : "sns:Publish",
          "Resource" : "arn:aws:sns:${var.region}:${var.id}:gd_notification"
        }
      ]
    }
  )

}


# a Iam_role
resource "aws_iam_role" "gd_notification_role" {
  name = "gd_notification_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })

}


# attach custom policy to a role
resource "aws_iam_role_policy_attachment" "gd_notification_custom_attachment" {
  role       = aws_iam_role.gd_notification_role.name
  policy_arn = aws_iam_policy.gd_notification_policy.arn
}

# attach aws managed policy to a role
resource "aws_iam_role_policy_attachment" "gd_notification_managed_attachment" {
  role       = aws_iam_role.gd_notification_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


# data "archive_file" "lambda" {
#   type        = "zip"
#   source_file = "lambda_function.py"
#   output_path = "lambda_function.zip"
# }

# Lambda function with role
resource "aws_lambda_function" "gd_notification_lambda" {

  filename      = "lambda_function.zip"
  function_name = "gd_notification_function"
  role          = aws_iam_role.gd_notification_role.arn
  handler       = "lambda_function.lambda_handler"



  runtime = "python3.13"

  environment {
    variables = {
      APIKEY      = "271e8ba2a69d42dd8613474278adfe2f"
      BASEURL     = "https://api.sportsdata.io/v3/nba/scores/json/GamesByDate/"
      SNSTOPICARN = aws_sns_topic.gd_notification.arn
    }
  }
}


# EventBridge (Scheduler) and its roles and policy

# EventBridge policy
resource "aws_iam_policy" "gd_event_scheduler_policy" {
  name = "gd_eventbridge_schedular_policy"
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "lambda:InvokeFunction"
          ],
          "Resource" : [
            "${aws_lambda_function.gd_notification_lambda.arn}:*",
            "${aws_lambda_function.gd_notification_lambda.arn}"
          ]
        }
      ]
    }
  )
}


# EventBridge Role
resource "aws_iam_role" "gd_event_scheduler_role" {
  name = "gd_eventBridge_role"
  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Principal" : {
            "Service" : "scheduler.amazonaws.com"
          },
          "Action" : "sts:AssumeRole",
          "Condition" : {
            "StringEquals" : {
              "aws:SourceAccount" : "${var.id}"
            }
          }
        }
      ]
    }
  )


}

# Attaching policy to role
resource "aws_iam_role_policy_attachment" "gd_event_scheduler_attachment" {
  role       = aws_iam_role.gd_event_scheduler_role.name
  policy_arn = aws_iam_policy.gd_event_scheduler_policy.arn
}

# EventBridge set up
resource "aws_scheduler_schedule" "gd_scheduler" {
  name = "gd_schedular"


  schedule_expression = "cron(0 22-23/2,0-2/1 12-13 1 ? 2025)"

  target {
    arn      = aws_lambda_function.gd_notification_lambda.arn
    role_arn = aws_iam_role.gd_event_scheduler_role.arn
  }

  flexible_time_window {
    mode = "OFF"
  }
}
