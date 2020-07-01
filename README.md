# Analytical Platform IAM

Defines IAM Users in the Analytical Platform's Landing AWS Account and gives them permissions to switch role (AssumeRole) into other Analytical Platform AWS accounts.

The Landing Account is for defining IAM Users and their permissions. The security of IAM is paramount therefore:

* this IAM configuration is isolated in its own AWS Account, away from the rest of the platform - don't put other things in this account!
* only a small number of people can modify it
* deployment is automated and stored in code to be auditable

In addition, since Analytical Platform is spread over multiple other AWS Accounts, it is convenient for each developer/devops to have one set of User creds, rather than having one for each AWS Account.

At some point it would be good to setup these Users to have auth using some corporate SSO.

## Contents of this repo

### IAM Terraform definitions

Terraform definitions, that are applied in multiple AWS Accounts.

In the Landing AWS Account:

* IAM Users - for use by administrators of the Analytical Platform
* Those Users are added to Groups, which are given Policies, that allow them to:
  * switch role (AssumeRole) into certain roles in certain remote accounts
  * manage their own creds

In remote AWS accounts:

* Roles that Users in the Landing Account switch role (AssumeRole) into

### IAM Pipeline

Terraform definition of a CodePipeline, that does the Continuous Deployment of "IAM Terraform definitions"

Folder: [pipeline](pipeline/README.md)

### Init-roles

Terraform definitions of:

* Roles to be created in remote AWS accounts, so that the IAM terraform can AssumeRole in - [INIT-ROLES](init-roles/README.md)

Folder: [INIT-ROLES](init-roles/README.md)

## AWS Account setup

Before you can apply the "IAM Terraform definitions", every AWS account that it [specifies](vars/landing.tfvars) needs the Init-roles terraform applied - see: [INIT-ROLES](init-roles/README.md)

## Usage

As an example of usage, we'll create a user, then put it in a new "AWS Glue Administrators" group in the Landing AWS Account. We'll also create a role with relevant permissions in the dev aws account for members of that group to assume.

### User creation

Typically a dev or data engineer will need a user account. This is an IAM User in the Landing (AWS) account, with which you can switch role [assume role]() into the other AP AWS accounts.

To create yourself an IAM User, add a aws_iam_user resource to [users.tf](users.tf) e.g.:

```hcl
resource "aws_iam_user" "bob" {
  name          = "bob@digital.justice.gov.uk"
  force_destroy = true
}
```

Create a PR with this change (and you probably want to add it to some existing groups in this same PR - see next section).

Ask for this PR to be reviewed, and then merge it. Now the AWS CodePipeline will spend a couple of minutes doing the `terraform plan`, then need approval before it is applied. So you should ask one of the [Landing Account Restricted Admin group](https://github.com/ministryofjustice/analytical-platform-iam/blob/master/assume-landing.tf#L21) to approve the IAM change, and provide links to your PR and [Approving an IAM change](#approving-an-iam-change)

### Approve and apply an IAM change

To approve and apply an IAM change, an admin (from the 'restricted admin group') should:

* Login to AP's Landing AWS account and switch to [restricted-admin@landing](https://signin.aws.amazon.com/switchrole?account=analytical-platform-landing&roleName=restricted-admin-landing&displayName=restricted-admin@landing)
* In CodePipeline, in region `eu-west-1`, go to the pipeline `iam-pipeline`
* On the 'Plan' step, check the output of 'terraform plan' looks right
* On the 'Approve' step, click 'Review' and 'Approve'
* Wait 2 minutes to ensure the 'Apply' step succeeds

For a new user:

* in IAM, find the new User and:
  * in tab "Security credentials" "Console password" select "Manage"
  * under "Console access" select "Enable"
  * under "Require password reset" *check* the box
  * select "Apply"
* Email the user their AWS console password and the link to: [First login](#first-login)

### First login

You should have received your AWS console password - see above.

Access the AWS console here: https://analytical-platform-landing.signin.aws.amazon.com/console

* Account ID: `analytical-platform-landing`
* IAM username: `bob@digital.justice.gov.uk` (the name you specified in users.tf)
* Password: (was sent to you)

Log-in and it'll prompt you to change your password. The password needs to be: minimum 16 characters, including uppercase, a number and a symbol from: `!@#$%^&*()_+-=[]{}|'`.

(If it does not prompt you to change your password then you'll need to come back to this after you've setup MFA and logged out and in again)

You MUST set-up MFA - it is required to be able to switch role. To set-up MFA:

1. In AWS console's top bar, click your username and then "My Security Credentials"
2. Click button "Assign MFA device"
3. etc... (Full instructions are [here](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_mfa_enable.html))

Now you MUST log out of the AWS Console and back in again, so that it registers you've used MFA, before you can do anything else.

Note: Managing users with Terraform (e.g. passwords) is still at best clunky, so we decided that admins should do this with the AWS console instead.

### Existing groups

Your user can't do much until you add it to a group, which are setup to let the user 'assume' into a role with an attached policy (i.e. permissions). Existing groups are listed in the `assume-*.tf` files in this repo - one for each AWS account.

* [assume-data.tf](assume-data.tf) - 'data' account - includes existing alpha & dev environments
* [assume-landing.tf](assume-landing.tf) - landing / IAM account
* [assume-dev.tf](assume-dev.tf) - future dev environment
* [assume-prod.tf](assume-prod.tf) - future prod environment

### New/editing groups

#### Variables

Group names should be held in variables (and we may well refer to it several times), so we'll put it in [variables.tf](variables.tf). For example we'll create a group called `glue-admins`
You would add something like below to [variables.tf](variables.tf)

```hcl
## Glue Admins

variable "glue_admins_name" {
  default = "glue-admins"
}
```

#### Policies

Create a policy for a *purpose* and attach it to multiple user groups. This is better than a group having one big policy, because it means you're likely to end up putting lots of users in bigger groups, which is against the 'principle of least privilege'. You can iterate on policies that already exist in this repository or create a policy document from scratch.

Policy files should be prefixed with `policy-` for clarity. For example `policy-glue-admins.tf`

To use a managed policy instead, you can refer to the policy by using it's ARN with the parameter `role_policy_arn`

```hcl
module "add_glue_admins_role_in_dev" {
  source = "modules/role"
  providers = {
    aws = "aws.dev"
  }

  role_name                 = "${var.glue_admins_name}-${local.dev}"
  landing_account_id        = "${var.landing_account_id}"
  role_policy_arn           = "arn:aws:iam::aws:policy/AWSGlueConsoleFullAccess"
}
```

#### Roles and Groups

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
    "${aws_iam_user.bob.name}",
    "${aws_iam_user.alice.name}",
  ]
}

module "add_glue_admins_role_in_dev" {
  source = "modules/role"
  providers = {
    aws = "aws.dev"
  }

  role_name                 = "${var.glue_admins_name}-${local.dev}"
  landing_account_id        = "${var.landing_account_id}"
  role_policy               = "${data.aws_iam_policy_document.glue_admins.json}"
}
```


### Authenticating

#### AWS Console

Once you've [created your user](#User-creation) you have access to the [AWS console for the Landing AWS Account](https://analytical-platform-landing.signin.aws.amazon.com/console).

From this account you can click on your user menu and then "switch role" to a role in another AWS account. e.g. to account `mojanalytics` as `restricted-admin-data`.

Alternatively just use these links:
* [read-only@data](https://signin.aws.amazon.com/switchrole?account=mojanalytics&roleName=read-only-data&displayName=read-only@data) (NB This one doesn't work currently)
* [restricted-admin@data](https://signin.aws.amazon.com/switchrole?account=mojanalytics&roleName=restricted-admin-data&displayName=restricted-admin@data)
* [billing-viewer@data](https://signin.aws.amazon.com/switchrole?account=mojanalytics&roleName=billing-viewer&displayName=billing-viewer@data)
* [read-only@landing](https://signin.aws.amazon.com/switchrole?account=analytical-platform-landing&roleName=read-only-landing&displayName=read-only@landing)
* [restricted-admin@landing](https://signin.aws.amazon.com/switchrole?account=analytical-platform-landing&roleName=restricted-admin-landing&displayName=restricted-admin@landing)
* [data-engineers-hmcts@mojanalytics](https://signin.aws.amazon.com/switchrole?account=mojanalytics&roleName=data-engineers-hmcts&displayName=data-engineers-hmcts@mojanalytics)
* [data-engineers-prisons@mojanalytics](https://signin.aws.amazon.com/switchrole?account=mojanalytics&roleName=data-engineers-prisons&displayName=data-engineers-prisons@mojanalytics)
* [data-engineers-probation@mojanalytics](https://signin.aws.amazon.com/switchrole?account=mojanalytics&roleName=data-engineers-probation&displayName=data-engineers-probation@mojanalytics)
* [data-engineers-corporate@mojanalytics](https://signin.aws.amazon.com/switchrole?account=mojanalytics&roleName=data-engineers-corporate&displayName=data-engineers-corporate@mojanalytics)

Please use the 'read-only' roles by default - only use 'restricted-admin' when you need to make a change.

#### AWS CLI

Optionally you can also setup an AWS access key on your machine. This enables you to use the AWS Command Line Interface (AWS CLI) and other programmatic calls to the AWS API.

To setup an AWS access key on your machine:

1. If you have not installed the AWS CLI, which gives you the `aws` command, install it on your machine - see [AWS Command Line Interface](https://aws.amazon.com/cli/)
2. Login to the AWS Console (see above)
3. Select your username in the top-bar and in this drop-down menu select "My Security Credentials". (If you've switched to another account or role, first you'll have to select "Back to david.read@digital.justice.gov.uk", or similar)
4. In the section "Access keys for CLI, SDK, & API access" select "Create access key"
5. It should say "Your new access key is now available". Leave this on your screen while you configure these details into you command-line in the following step.
6. Run `aws configure`, with the suggested profile name 'landing' and put in your Access Key ID and Secret Access Key seen on the AWS Console:

    ```bash
    $ aws configure --profile landing
    AWS Access Key ID [None]: AKIA...
    AWS Secret Access Key [None]: Ti2d7...
    Default region name [None]: eu-west-1
    Default output format [None]:
    ```

   This will add the creds to ~/.aws/credentials and default region to ~/.aws/config

This profile is needed, but not much use on its own - you only use this landing account as a hop, from which you switch to a role in a destination account. To use the AWS CLI with the destination account & role, you have a couple of options - see the following sections.

#### AWS CLI using profile

You can create a special AWS profile that effectively logs you into your landing account and then switches you to the destination account & role. This is convenient!

Simply add these lines to your `~/.aws/config`:

```ini
[profile data]
region=eu-west-1
role_arn=arn:aws:iam::593291632749:role/restricted-admin-data
source_profile=landing

[profile landing-admin]
region=eu-west-1
role_arn=arn:aws:iam::335823981503:role/restricted-admin-landing
source_profile=landing
```
where `source_profile` references the 'landing' profile in `~/.aws/credentials`

So to access the 'data' AWS account with the `restricted-admin-data` role, you just need to select the `data` profile. Check it works:

```bash
$ export AWS_PROFILE=data
$ aws sts get-caller-identity
{
    "UserId": "AROAYUIXP4BW2DK7Y7ZLB:botocore-session-1593453280",
    "Account": "593291632749",
    "Arn": "arn:aws:sts::593291632749:assumed-role/restricted-admin-data/botocore-session-1593453280"
}
```

For more info, see: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-role.html

NB this method works for running aws cli commands, but **it doesn't work for terraform commands**. For terraform, use assume-role or AWS Vault - see below.

#### AWS CLI using assume-role

In the AWS console (Landing account) you can create an access key, which can be used with the AWS cli tool `aws`

[awscli]: https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html
[aws profile]: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html

If you want to run tests or apply terraform config from your local machine you'll first need to authenticate

##### Prerequisites

* Firstly ensure you have an existing `IAM` user account in the Landing account. See [Usage](#usage)

* Ensure you have installed the [awscli][awscli]

* **Optional**: Create a profile for your landing user account. See [Creating an AWS Profile][aws profile]

**Note** you can set this profile as your default by assigning to the `AWS_PROFILE` environment variable

__Request temporary credentials to assume the appropriate role in the desired account__:

```bash
aws sts assume-role --role-arn "arn:aws:iam::593291632749:role/restricted-admin-data" --role-session-name data-session
```

__Set temporary credentials as environment variables__:

```bash
export AWS_ACCESS_KEY_ID=ASIAX........
export AWS_SECRET_ACCESS_KEY=0vwDrU5..........
export AWS_SESSION_TOKEN="FQoGZXIvYXdzEHQaDHBH......."
```

__Did it work?__

```bash
aws sts get-caller-identity
```

**Note** If using credentials to apply terraform config, you'll need to pass the flag `-lock=false` as the role you're assuming will not have
permissions to access the lock table.. i.e. `terraform plan -lock=false`

__When finished!__:

Your credentials are temporary and will expire after 1 hour.  You'll need to repeat the process to be able to authenticate after this time

Unset your credentials:

```bash
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
```

#### AWS CLI with AWS Vault

Since the [AWS CLI using assume-role](#aws-cli-using-assume-role) method is burdensome, consider using AWS Vault: https://github.com/99designs/aws-vault It is convenient single command to do an Assume Role. And it has the benefit of storing secrets in the Mac keychain instead of a file on disk.

1. [Install AWS Vault](https://github.com/99designs/aws-vault#installing)
2. Add to AWS Vault your Landing Account's Access Key:
   ```bash
   aws-vault add landing
   ```
3. Test it:
   ```bash
   aws-vault exec landing -- aws sts get-caller-identity
   ```
3. For each role/account you want to switch to, you need a 'profile' setup in `~/.aws/config`. See the examples in [AWS CLI using profile](aws-cli-using-profile).
4. Run AWS CLI commands in the remote roles using the `aws-vault exec <profile> -- ` prefix, for example:

    ```bash
    aws-vault exec dev -- aws sts get-caller-identity
    ```

## Tests

This project is tested using the [Kitchen Terraform](https://github.com/newcontext-oss/kitchen-terraform) testing harness. Admittedly Kitchen is not ideally suited for IAM because [Inspec](https://www.inspec.io/docs/reference/resources/#aws-resources) has limited support.

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

Set your AWS profile to be the landing account and assume-role into the same account as the objects you're testing. (Kitchen will create AWS resources).

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
