################################################################################
# EC2 to Perform EKS Node Update
################################################################################
data "aws_iam_policy_document" "assume_role_ec2" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}


resource "aws_iam_policy" "eksNodeUpdater" {
  name        = "eksNodeUpdater"
  path        = "/"
  description = "Permissions required to execute userdata"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "eks:ListNodegroups",
          "eks:ListClusters",
          "eks:UpdateNodegroupVersion",
          "eks:DescribeCluster",
          "eks:DescribeNodegroup",
          "eks:DescribeUpdate",
          "logs:PutRetentionPolicy",
          "cloudformation:ListStacks",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:DescribeLaunchTemplates"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role" "eksNodeUpdater" {
  name               = "eksNodeUpdater"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.assume_role_ec2.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy", aws_iam_policy.eksNodeUpdater.arn]
}

resource "aws_iam_instance_profile" "eksNodeUpdater" {
  name = "eksNodeUpdater"
  role = aws_iam_role.eksNodeUpdater.name
}

resource "aws_security_group" "allow_outbound" {
  name        = "allow_outbound"
  vpc_id      = var.vpc_id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

}



data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*"]
  }
  
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_launch_template" "eksNodeUpdater" {
  name = "eksNodeUpdater"
  image_id = data.aws_ami.amazon_linux.id
  update_default_version = true

  iam_instance_profile {
    name = aws_iam_instance_profile.eksNodeUpdater.name 
  }


  instance_initiated_shutdown_behavior = "terminate"

  instance_type = "t2.micro"

  network_interfaces {
    associate_public_ip_address = true
    security_groups = [aws_security_group.allow_outbound.id]
    subnet_id = var.subnet_id  
  }
  
  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "eksNodeUpdater"
    }
  }


  user_data = filebase64("${path.module}/userdata.sh")
}


################################################################################
# Schedule and Launch EC2 
################################################################################


data "aws_iam_policy_document" "assume_role_lambda" {
  statement {
    sid    = "TrustPolicy"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = [
      "sts:AssumeRole"
    ]
  }
}


resource "aws_iam_role" "lambda_eksNodeUpdater" {
  name                 = "lambda_eksNodeUpdater"
  path                 = "/"
  assume_role_policy   = data.aws_iam_policy_document.assume_role_lambda.json
}

resource "aws_iam_policy" "lambda_eksNodeUpdater" {
  name        = "lambda_eksNodeUpdater"
  path        = "/"
  description = "Permissions required to launch eksNodeUpdater"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:DescribeImages",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:DescribeInstances",
          "ec2:DescribeVpcs",
          "ec2:CreateSecurityGroup",
          "ec2:CreateTags",
          "ec2:DescribeInstanceTypes",
          "ec2:RunInstances",
          "ec2:DescribeSubnets",
          "ec2:DescribeKeyPairs",
          "ec2:DescribeSecurityGroups",
          "ec2:AssociateIamInstanceProfile",
          "ec2:ReplaceIamInstanceProfileAssociation"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
      "Effect":"Allow",
      "Action":"iam:PassRole",
      "Resource":"${aws_iam_role.eksNodeUpdater.arn}"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_eksNodeUpdater" {

  role       = aws_iam_role.lambda_eksNodeUpdater.name
  policy_arn = aws_iam_policy.lambda_eksNodeUpdater.arn
  #policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}



resource "aws_cloudwatch_event_rule" "scheduled" {
  name                = "eksNodeUpdater_schedule"
  schedule_expression = var.run_schedule
}

resource "aws_cloudwatch_event_target" "triggerLambda" {
  rule      = "${aws_cloudwatch_event_rule.scheduled.name}"
  target_id = "lambda"
  arn       = "${aws_lambda_function.launcheksNodeUpdater.arn}"
}

resource "aws_lambda_permission" "invokeLambdafromCloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.launcheksNodeUpdater.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.scheduled.arn}"
}

resource "aws_lambda_function" "launcheksNodeUpdater" {
  role             = aws_iam_role.lambda_eksNodeUpdater.arn
  runtime = "python3.9"
  filename      = "${path.module}/run.zip"
  function_name = "launch_eksNodeUpdater"
  handler       = "run.lambda_handler"
  timeout       = 180
  source_code_hash = filebase64sha256("${path.module}/run.zip")

}
