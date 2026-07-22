locals {
  aws_suffix                  = "REDACTED_ACCOUNT_ID"
  terraform_state_bucket_name = "terraform-state-weirdo-bucket-${local.aws_suffix}"
}
