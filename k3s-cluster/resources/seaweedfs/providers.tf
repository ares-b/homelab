# SeaweedFS speaks the S3 API, so the AWS provider manages buckets and CORS.
# Validation skips are required because SeaweedFS has no STS/IAM metadata endpoints.
provider "aws" {
  access_key = var.seaweedfs_admin_access_key
  secret_key = var.seaweedfs_admin_secret_key
  region     = "seaweedfs"

  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_region_validation      = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true

  endpoints {
    s3 = var.seaweedfs_s3_endpoint
  }
}
