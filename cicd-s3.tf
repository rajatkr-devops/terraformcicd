resource "aws_s3_bucket" "codepipeline_artifacts" {
  bucket = "pipeline-artifacts-rajat0021"
  acl    = "private"
} 