provider "aws" {
    access_key = ""
    secret_key = ""
    region = "us-east-1"
}

data "archive_file" "greet_lambda" {
    type            = "zip"
    source_file     = "greet_lambda.py"
    output_path     = "greet_lambda.zip"
}

resource "aws_lambda_function" "greet_lambda" {
    filename        = "greet_lambda.zip"
    function_name   = "lambda_handler"
    handler         = "greet_lambda.lambda_handler"
    runtime         = "python3.8"
    role            = aws_iam_role.lambda_exec.arn
    depends_on      = [aws_iam_role_policy_attachment.lambda_logs]

    environment {
        variables = {
            greeting = "Ole "
        }
    }
}

resource "aws_iam_policy" "lambda_logging" {
    name            = "lambda_logging"
    path            = "/"
    description     = "IAM policy for logging from a lambda"

    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*",
            "Effect": "Allow"
        }
    ]
}
EOF
}

resource "aws_iam_role" "lambda_exec" {
    name = "udacity_part2"

    assume_role_policy = <<EOF
{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Action": "sts:AssumeRole",
                "Principal": {
                    "Service": "lambda.amazonaws.com"
                },
                "Effect": "Allow",
                "Sid": ""
            }
        ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
    role        = aws_iam_role.lambda_exec.name
    policy_arn  = aws_iam_policy.lambda_logging.arn
}

resource "aws_iam_role_policy" "lambda-cloudwatch-log-group" {
    name = "dhayes-cloudwatch-log-group"
    role = aws_iam_role.lambda_exec.name
    policy = data.aws_iam_policy_document.cloudwatch-log-group-lambda.json
}

data "aws_iam_policy_document" "cloudwatch-log-group-lambda" {
    statement {
        actions = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
        ]

        resources = [
            "arn:aws:logs:::*",
        ]
    }
}


resource "aws_cloudwatch_event_rule" "demo_lambda_every_one_minute" {
    name = "demo_lambda_every_one_minute"
    depends_on = [
        aws_lambda_function.greet_lambda
    ]
    schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "demo_lambda" {
#  target_id = demo_lambda
  rule = aws_cloudwatch_event_rule.demo_lambda_every_one_minute.name
  arn = aws_lambda_function.greet_lambda.arn
}

resource "aws_lambda_permission" "demo_lambda_every_one_minute" {
  statement_id = "AllowExecutionFromCloudWatch"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.greet_lambda.function_name
  principal = "events.amazonaws.com"
  source_arn = aws_cloudwatch_event_rule.demo_lambda_every_one_minute.arn
} 
