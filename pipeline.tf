resource "aws_codecommit_repository" "test" {
    repository_name = "nonprodinfrarepo"
    description = "this is a terraform repo for non prod"  
}

resource "aws_cloudwatch_event_rule" "codecommit_activity" {
  
  description = "Detect commits to CodeCommit repo of $ on branch "

  event_pattern = <<PATTERN
{
  "source": [ "aws.codecommit" ],
  "detail-type": [ "CodeCommit Repository State Change" ],
  "resources": [ "${aws_codecommit_repository.test.arn}" ],
  "detail": {
     "event": [
       "referenceCreated",
       "referenceUpdated"
      ],
     "referenceType":["branch"],
     "referenceName": ["master"]
  }
}
PATTERN
}

resource "aws_cloudwatch_event_target" "cloudwatch_triggers_pipeline" {
#   target_id = "${var.tag}-commits-trigger-pipeline"
  rule = aws_cloudwatch_event_rule.codecommit_activity.name
  arn = aws_codepipeline.cicd_pipeline.arn
  role_arn = aws_iam_role.cloudwatch_ci_role.arn
}

# Allows the CloudWatch event to assume roles
resource "aws_iam_role" "cloudwatch_ci_role" {
  name = "cloudwatch-ci-"

  assume_role_policy = <<DOC
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "events.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
DOC
}
data "aws_iam_policy_document" "cloudwatch_ci_iam_policy" {
  statement {
    actions = [
      "iam:PassRole"
    ]
    resources = [
      "*"
    ]
  }
  statement {
    # Allow CloudWatch to start the Pipeline
    actions = [
      "codepipeline:StartPipelineExecution"
    ]
    resources = [
      aws_codepipeline.cicd_pipeline.arn
    ]
  }
}
resource "aws_iam_policy" "cloudwatch_ci_iam_policy" {
  name = "cloudwatch-ci-"
  policy = data.aws_iam_policy_document.cloudwatch_ci_iam_policy.json
}
resource "aws_iam_role_policy_attachment" "cloudwatch_ci_iam" {
  policy_arn = aws_iam_policy.cloudwatch_ci_iam_policy.arn
  role = aws_iam_role.cloudwatch_ci_role.name
}

resource "aws_iam_role" "tf-codepipeline-role" {
  name = "tf-codepipeline-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

}

data "aws_iam_policy_document" "tf-cicd-pipeline-policies" {
    statement{
        sid = ""
        actions = ["codestar-connections:UseConnection"]
        resources = ["*"]
        effect = "Allow"
    }
    statement{
        sid = ""
        actions = ["cloudwatch:*", "s3:*", "codebuild:*"]
        resources = ["*"]
        effect = "Allow"
    }
}

resource "aws_iam_policy" "tf-cicd-pipeline-policy" {
    name = "tf-cicd-pipeline-policy"
    path = "/"
    description = "Pipeline policy"
    policy = data.aws_iam_policy_document.tf-cicd-pipeline-policies.json
}

resource "aws_iam_role_policy_attachment" "tf-cicd-pipeline-attachment" {
    policy_arn = aws_iam_policy.tf-cicd-pipeline-policy.arn
    role = aws_iam_role.tf-codepipeline-role.id
}

resource "aws_iam_role_policy_attachment" "tf-cicd-pipeline-attachment2" {
    policy_arn  = "arn:aws:iam::aws:policy/AWSCodeCommitFullAccess"
    role        = aws_iam_role.tf-codepipeline-role.id
}

resource "aws_iam_role_policy_attachment" "tf-cicd-pipeline-attachment3" {
    policy_arn  = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
    role        = aws_iam_role.tf-codepipeline-role.id
}

resource "aws_iam_role" "tf-codebuild-role" {
  name = "tf-codebuild-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

}

data "aws_iam_policy_document" "tf-cicd-build-policies" {
    statement{
        sid = ""
        actions = ["logs:*", "s3:*", "codebuild:*", "secretsmanager:*","iam:*"]
        resources = ["*"]
        effect = "Allow"
    }
}

resource "aws_iam_policy" "tf-cicd-build-policy" {
    name = "tf-cicd-build-policy"
    path = "/"
    description = "Codebuild policy"
    policy = data.aws_iam_policy_document.tf-cicd-build-policies.json
}

resource "aws_iam_role_policy_attachment" "tf-cicd-codebuild-attachment1" {
    policy_arn  = aws_iam_policy.tf-cicd-build-policy.arn
    role        = aws_iam_role.tf-codebuild-role.id
}

resource "aws_iam_role_policy_attachment" "tf-cicd-codebuild-attachment2" {
    policy_arn  = "arn:aws:iam::aws:policy/PowerUserAccess"
    role        = aws_iam_role.tf-codebuild-role.id
}
resource "aws_s3_bucket" "codepipeline_artifacts" {
  bucket = "pipeline-artifacts-emm"
  acl    = "private"
} 

resource "aws_codebuild_project" "tf-plan" {
  name          = "tf-cicd-plan2"
  description   = "Plan stage for terraform"
  service_role  = aws_iam_role.tf-codebuild-role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:5.0"
    type                        = "LINUX_CONTAINER"
  image_pull_credentials_type = "CODEBUILD"

      environment_variable {
        name = "TERRAFORM_VERSION"
        value = "1.1.9"
      }
      environment_variable {
        name = "TF_COMMAND"
        value = "apply"
        type = "PLAINTEXT"
      }
    }

    logs_config {
    cloudwatch_logs {
      status = "ENABLED"
    }

    s3_logs {
      encryption_disabled = false
      status              = "DISABLED"
    }
  }
 
 source {
     type   = "CODEPIPELINE"
     buildspec = "buildspec.yml"
 }
 tags = {
   "Terraform" = "true"
 }
}

resource "aws_codebuild_project" "tf-plan-deploy" {
  name          = "tf-cicd-deploy"
  description   = "Plan stage for terraform"
  service_role  = aws_iam_role.tf-codebuild-role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:5.0"
    type                        = "LINUX_CONTAINER"
  image_pull_credentials_type = "CODEBUILD"

      environment_variable {
        name = "TERRAFORM_VERSION"
        value = "1.1.9"
      }
      environment_variable {
        name = "TF_COMMAND"
        value = "apply"
        type = "PLAINTEXT"
      }
    }

    logs_config {
    cloudwatch_logs {
      status = "ENABLED"
    }

    s3_logs {
      encryption_disabled = false
      status              = "DISABLED"
    }
  }
 
 source {
     type   = "CODEPIPELINE"
     buildspec = "buildspecapply.yml"
 }
 tags = {
   "Terraform" = "true"
 }
}
resource "aws_codepipeline" "cicd_pipeline" {

    name = "tf-cicd"
    role_arn = aws_iam_role.tf-codepipeline-role.arn

    artifact_store {
        type="S3"
        location = aws_s3_bucket.codepipeline_artifacts.id
    }

    stage {
        name = "Source"
        action{
            name = "Source"
            category = "Source"
            owner = "AWS"
            provider = "CodeCommit"
            version = "1"
            run_order = 1
            output_artifacts = ["tf-code"]
            configuration = {
                # FullRepositoryId = "rajatkr-devops/terraform"
                BranchName   = "master"
                RepositoryName = aws_codecommit_repository.test.id
                PollForSourceChanges = "false"
                # ConnectionArn = var.codestar_connector_credentials
                # OutputArtifactFormat = "CODE_ZIP"
            }
        }
    }

    stage {
        name ="Plan"
        action{
            name = "Build"
            category = "Build"
            provider = "CodeBuild"
            version = "1"
            owner = "AWS"
            input_artifacts = ["tf-code"]
            configuration = {
                ProjectName = "tf-cicd-plan2"
            }
        }
    }
    stage {
  name = "Manual_Approval"

  action {
    name     = "Manual-Approval"
    category = "Approval"
    owner    = "AWS"
    provider = "Manual"
    version  = "1"
  }
}

  stage {
    name = "Terraform_Apply"

    action {
      name            = "Terraform-Apply"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
            input_artifacts = ["tf-code"]
            configuration = {
                ProjectName = "tf-cicd-deploy"
      }
    }
  }
#     stage {
#         name ="Deploy"
#         action{
#             name = "Deploy"
#             category = "Build"
#             provider = "CodeBuild"
#             version = "1"
#             owner = "AWS"
#             input_artifacts = ["tf-code"]
#             configuration = {
#                 ProjectName = "tf-cicd-apply"
#             }
#         }
#     }

 }

 terraform{
    backend "s3" {
        bucket = "rajat-terraform-state-backend01"
        encrypt = true
        # dynamodb_table = "terraform-state"
        key = "pipeline/terraform-tfstate"
        region = "us-east-2"
    }
}