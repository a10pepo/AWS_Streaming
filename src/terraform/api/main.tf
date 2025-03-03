resource "aws_ecr_repository" "api_repository" {
  name = "my-api-repo"
  force_delete = true
}

resource "aws_iam_role" "ecr_push_role" {
  name = "ecr-push-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecr_push_policy" {
  name = "ecr-push-policy"
  role = aws_iam_role.ecr_push_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ],
        Effect = "Allow",
        Resource = aws_ecr_repository.api_repository.arn
      }
    ]
  })
}

resource "null_resource" "docker_build_and_push" {
  triggers = {
    always_run = "${timestamp()}"
  }    
  provisioner "local-exec" {
    command = <<EOT
      aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin ${aws_ecr_repository.api_repository.repository_url}
      docker buildx build --platform linux/amd64 -t my-api-repo /Users/pedro.nieto/Documents/CPT/AWS_Streaming/src/terraform/api/docker
      docker tag my-api-repo:latest ${aws_ecr_repository.api_repository.repository_url}:latest
      docker push ${aws_ecr_repository.api_repository.repository_url}:latest
    EOT
  }
  depends_on = [aws_ecr_repository.api_repository]
}

data "aws_ecr_image" "my_image" {
  repository_name = aws_ecr_repository.api_repository.name
  image_tag       = "latest"
  depends_on      = [null_resource.docker_build_and_push]
}

resource "null_resource" "trigger_apprunner_deployment" {
  triggers = {
    image_digest = "${data.aws_ecr_image.my_image.image_digest}"
  }
  depends_on = [null_resource.docker_build_and_push]
}

resource "aws_iam_role" "app_runner_role" {
  name = "app-runner-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "build.apprunner.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      },
      {
        Effect: "Allow",
        Principal: {
          Service: "tasks.apprunner.amazonaws.com"
        },
        Action: "sts:AssumeRole"
    }
    ]
  })
}



resource "aws_iam_role_policy" "app_runner_policy" {
  name = "app-runner-policy"
  role = aws_iam_role.app_runner_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetAuthorizationToken",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue",
          "kms:Decrypt*"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "sns:*",
          "sqs:*"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "rds:*"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_apprunner_service" "my_service" {
  service_name = "my-app-runner-service"
  source_configuration {
    authentication_configuration {
      access_role_arn = aws_iam_role.app_runner_role.arn
    }
    auto_deployments_enabled = true
    image_repository {
      image_identifier      = "${aws_ecr_repository.api_repository.repository_url}:latest"
      image_repository_type = "ECR"
      image_configuration {
        port = "8000"
      }
    }
  }
  instance_configuration {
    instance_role_arn = aws_iam_role.app_runner_role.arn
    cpu = "1024"
    memory = "2048"
  }
  lifecycle {
    create_before_destroy = true
  }
  depends_on = [ null_resource.docker_build_and_push, aws_iam_role.app_runner_role , aws_iam_role_policy.app_runner_policy] 
}