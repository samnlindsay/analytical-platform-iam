## Analytical Platform Tech

resource "aws_iam_user" "mikael" {
  name          = "mikael.allison@digital.justice.gov.uk"
  force_destroy = true
}

resource "aws_iam_user" "shojul" {
  name          = "shojul.hassan@digital.justice.gov.uk"
  force_destroy = true
}

resource "aws_iam_user" "ravi" {
  name          = "ravi.kotecha@digital.justice.gov.uk"
  force_destroy = true
}

resource "aws_iam_user" "aldo" {
  name          = "aldo.giambelluca@digital.justice.gov.uk"
  force_destroy = true
}
