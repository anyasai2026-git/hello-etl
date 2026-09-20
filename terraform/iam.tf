data "aws_iam_policy_document" "glue_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "glue" {
  name               = "${local.name}-glue-role"
  assume_role_policy = data.aws_iam_policy_document.glue_assume.json
  tags               = local.tags
}

data "aws_iam_policy_document" "glue_s3" {
  statement {
    sid     = "ReadRawAndScripts"
    actions = ["s3:GetObject", "s3:ListBucket"]
    resources = [
      aws_s3_bucket.raw.arn, "${aws_s3_bucket.raw.arn}/*",
      aws_s3_bucket.scripts.arn, "${aws_s3_bucket.scripts.arn}/*",
    ]
  }
  statement {
    sid     = "WriteProcessedAndTmp"
    actions = ["s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
    resources = [
      aws_s3_bucket.processed.arn, "${aws_s3_bucket.processed.arn}/*",
      "${aws_s3_bucket.scripts.arn}/tmp/*",
    ]
  }
}

resource "aws_iam_role_policy" "glue_s3" {
  name   = "${local.name}-glue-s3"
  role   = aws_iam_role.glue.id
  policy = data.aws_iam_policy_document.glue_s3.json
}

resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}
