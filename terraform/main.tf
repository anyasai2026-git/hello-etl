terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

locals {
  name = "${var.project}-${var.env}"
  tags = {
    Project     = var.project
    Environment = var.env
    ManagedBy   = "terraform"
  }
}

resource "random_id" "suffix" {
  byte_length = 3
}

resource "aws_s3_bucket" "raw" {
  bucket = "${local.name}-raw-${random_id.suffix.hex}"
  tags   = local.tags
}

resource "aws_s3_bucket" "processed" {
  bucket = "${local.name}-processed-${random_id.suffix.hex}"
  tags   = local.tags
}

resource "aws_s3_bucket" "scripts" {
  bucket = "${local.name}-scripts-${random_id.suffix.hex}"
  tags   = local.tags
}

resource "aws_s3_bucket_public_access_block" "all" {
  for_each                = { raw = aws_s3_bucket.raw.id, processed = aws_s3_bucket.processed.id, scripts = aws_s3_bucket.scripts.id }
  bucket                  = each.value
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "all" {
  for_each = { raw = aws_s3_bucket.raw.id, processed = aws_s3_bucket.processed.id, scripts = aws_s3_bucket.scripts.id }
  bucket   = each.value
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_object" "glue_script" {
  bucket = aws_s3_bucket.scripts.id
  key    = "glue_jobs/customers_etl.py"
  source = "${path.module}/../glue_jobs/customers_etl.py"
  etag   = filemd5("${path.module}/../glue_jobs/customers_etl.py")
}

resource "aws_glue_job" "customers_etl" {
  name     = "${local.name}-customers-etl"
  role_arn = aws_iam_role.glue.arn

  glue_version      = "5.0"
  worker_type       = "G.1X"
  number_of_workers = 2

  command {
    name            = "glueetl"
    python_version  = "3"
    script_location = "s3://${aws_s3_bucket.scripts.id}/${aws_s3_object.glue_script.key}"
  }

  default_arguments = {
    "--raw_path"                         = "s3://${aws_s3_bucket.raw.id}/incoming/customers_sample.csv"
    "--processed_path"                   = "s3://${aws_s3_bucket.processed.id}/customers/"
    "--job-language"                     = "python"
    "--enable-metrics"                   = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--TempDir"                          = "s3://${aws_s3_bucket.scripts.id}/tmp/"
  }

  tags = local.tags
}
