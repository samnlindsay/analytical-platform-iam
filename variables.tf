variable "ap_accounts" {
  type        = map(string)
  description = "IDs of accounts to assume role into"
}

variable "restricted_admin_name" {
  default = "restricted-admin"
}

variable "landing_iam_role" {
  default = "landing-iam-role"
}

variable "audit_security_name" {
  default = "AuditAdminRole"
}

variable "data_engineers_name" {
  default = "data-engineers"
}

variable "hmcts_data_engineers_name" {
  default = "data-engineers-hmcts"
}

variable "prison_data_engineers_name" {
  default = "data-engineers-prisons"
}

variable "probation_data_engineers_name" {
  default = "data-engineers-probation"
}

variable "corporate_data_engineers_name" {
  default = "data-engineers-corporate"
}

locals {
  tags = {
    business-unit = "Platforms"
    application   = "analytical-platform"
    is-production = "true"
    owner         = "analytical-platform:analytics-platform-tech@digital.justice.gov.uk"
  }
}
