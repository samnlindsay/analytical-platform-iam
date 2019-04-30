# Analytical Platform IAM pipeline

Pipeline to create IAM resources in both landing and remote aws accounts

## Usage

* A push to the master branch of this repository will trigger the AWS Codepipeline.
* This clones the repository and passes it to the AWS Codebuild service.
* Codebuild (which is an ubuntu 18.04 container in this instance) runs a terraform plan and stores the plan file into the S3 Bucket created for the pipeline.
* The plan file should be reviewed and approved/rejected within Codepipeline.
* If approved, another codebuild envrionment will spin up, retrieve and apply the plan file stored in the S3 bucket.

The commands run within the codebuild stages are in the [buildspec-plan.yml](buildspec-plan.yml) and [buildspec-apply.yml](buildspec-apply.yml) files.

### Diagram:

![Image](iam-pipeline.png?raw=true)