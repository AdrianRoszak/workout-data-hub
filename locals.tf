locals {
  aws_suffix                  = "REDACTED_ACCOUNT_ID"
  bucket_name                 = "hello-world-weirdo-bucket-${local.aws_suffix}"
  terraform_state_bucket_name = "terraform-state-weirdo-bucket-${local.aws_suffix}"
}
