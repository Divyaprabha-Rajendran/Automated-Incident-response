resource "aws_cloudtrail" "forensic_account_trail" {
  name                          = "ForensicAccount-ManagementEventsTrail"
  s3_bucket_name                = aws_s3_bucket.s3_cloudtrail_logs.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  depends_on = [aws_s3_bucket_policy.s3_cloudtrail_logs]
}