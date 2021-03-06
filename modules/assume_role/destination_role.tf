data "aws_iam_policy_document" "destination" {
  statement {
    sid     = "AllowSelectedUsersAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    condition {
      test     = "BoolIfExists"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }

    principals {
      identifiers = var.user_arns
      type        = "AWS"
    }
  }
}

resource "aws_iam_role" "destination" {
  provider           = aws.destination
  name               = var.destination_role_name
  assume_role_policy = data.aws_iam_policy_document.destination.json
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each   = toset(var.managed_policies)
  provider   = aws.destination
  role       = aws_iam_role.destination.name
  policy_arn = each.key
}

resource "aws_iam_policy" "destination" {
  for_each    = var.aws_iam_policy_documents
  provider    = aws.destination
  name_prefix = each.key
  policy      = each.value.json
}

resource "aws_iam_role_policy_attachment" "destination" {
  for_each   = aws_iam_policy.destination
  provider   = aws.destination
  role       = aws_iam_role.destination.name
  policy_arn = each.value["arn"]
}
