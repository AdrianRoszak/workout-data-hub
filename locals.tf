data "aws_caller_identity" "current" {}

locals {
  aws_suffix                  = data.aws_caller_identity.current.account_id
  terraform_state_bucket_name = "terraform-state-weirdo-bucket-${local.aws_suffix}"
}
