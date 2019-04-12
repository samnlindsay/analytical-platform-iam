# Analytical Platform IAM
Analytical Platform IAM config

Creates IAM resources in both landing and remote aws accounts

### Prerequisites 

Before you continue see [IAM-ROLE](iam-role/README.md)

## Usage

As an example, lets create a group in the landing aws account for AWS Glue Administrators. We'll also create a role with  
relevant permissions in the dev aws account for members of that group to assume.

### Users:

You will need to add a user resource to [users.tf](users.tf) for each user

```hcl
resource "aws_iam_user" "sticky" {
  name          = "sticky@digital.justice.gov.uk"
  force_destroy = true
}
```

**Note**
Managing users with Terraform is still at best clunky. We made a decision to not manage user's credentials here. Instead 
we manage things like user's passwords in the console.  This is required for a user to be able to log in.

### Variables:

Common labels like names should be added to [variables.tf](variables.tf). For example if you wanted a group called `glue-admins` 
You would add something like below to [variables.tf](variables.tf)

```hcl
## Glue Admins

variable "glue_admins_name" {
  default = "glue-admins"
}
```

### Policies:

Rather than making use of managed policies its preferred that you construct a policy for purpose. Following the least privileged 
model you can iterate on policies that already exist in this repository or create a policy document from scratch. Policy 
files should be prefixed with `policy` for clarity. For example `policy-glue-admins.tf`

To use a managed policy instead, you can refer to the policy by using it's ARN with the parameter `role_policy_arn`

```hcl
module "add_glue_admins_role_in_dev" {
  source = "modules/role"

  assume_role_in_account_id = "${var.ap_accounts["dev"]}"
  role_name                 = "${var.glue_admins_name}-${local.dev}"
  landing_account_id        = "${var.landing_account_id}"
  role_policy_arn           = "arn:aws:iam::aws:policy/AWSGlueConsoleFullAccess"
}
```

### Roles and Groups:

The main portion of this repo provisions roles in remote aws accounts and groups where members can assume those roles. 
To do this you need to invoke both the `assume` and `role` modules. The `assume` module defines the group, it's members 
and the relationship with the role in the remote account. The `role` module defines the role and attached policies that 
get created in the remote account.

```hcl
module "assume_glue_admins_in_dev" {
  source = "modules/assume"

  assumed_role_name = "${var.glue_admins_name}-${local.dev}"

  assume_role_in_account_id = [
    "${var.ap_accounts["dev"]}",
  ]

  landing_account_id = "${var.landing_account_id}"
  group_name         = "${var.glue_admins_name}-${local.dev}"

  users = [
    "${aws_iam_user.sticky.name}",
    "${aws_iam_user.paste.name}",
  ]
}

module "add_glue_admins_role_in_dev" {
  source = "modules/role"

  assume_role_in_account_id = "${var.ap_accounts["dev"]}"
  role_name                 = "${var.glue_admins_name}-${local.dev}"
  landing_account_id        = "${var.landing_account_id}"
  role_policy               = "${data.aws_iam_policy_document.glue_admins.json}"
}
```

### Testing

This project uses the [Kitchen Terraform](https://github.com/newcontext-oss/kitchen-terraform) testing harness. Admittedly 
Its not suited for IAM as [Inspec](https://www.inspec.io/docs/reference/resources/#aws-resources) has limited support.

__TODO__:

Remove Kitchen in favour of [awspec](https://github.com/k1LoW/awspec)

__Tests__:

Install dependencies

```bash
bundle install
```

Lint

```bash
rubocop test/integration/analytical-platform-iam/controls
```

Ensure there are no fixtures remaining from previous test runs

```bash
bundle exec kitchen destroy
```

Create resources

```bash
bundle exec kitchen converge
```

Run tests

```bash
bundle exec kitchen verify
```

Tidy up

```bash
bundle exec kitchen destroy
```
