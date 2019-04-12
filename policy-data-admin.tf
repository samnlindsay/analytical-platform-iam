data "aws_iam_policy_document" "data_admin" {
  statement {
    sid    = "Read"
    effect = "Allow"

    actions = [
      "s3:Get*",
      "s3:List*",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "ObjectAdmin"
    effect = "Allow"

    actions = [
      "s3:AbortMultipartUpload",
      "s3:DeleteObject*",
      "s3:PutObject*",
      "s3:ReplicateObject",
      "s3:RestoreObject",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "Bucket"
    effect = "Allow"

    actions = [
      "s3:DeleteBucket*",
      "s3:PutBucket*",
      "s3:PutEncryptionConfiguration",
      "s3:PutMetricsConfiguration",
    ]

    resources = ["*"]
  }
}
