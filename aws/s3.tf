
###s3_access_logs

resource "aws_s3_bucket" "s3_access_logs" {
  bucket = "${data.aws_caller_identity.current.account_id}-s3-access-logs"

# lifecycle {
#     prevent_destroy = true
#   }

}

resource "aws_s3_bucket" "s3_cloudtrail_logs" {
  bucket = "${data.aws_caller_identity.current.account_id}-cloudtrail-logs"

#   lifecycle {
#     prevent_destroy = true
#   }
}

resource "aws_s3_bucket" "s3_vpc_flowlogs" {
  bucket = "${data.aws_caller_identity.current.account_id}-vpc-flowlogs"
}

resource "aws_s3_bucket" "s3_session_manager_logs" {
  bucket = "${data.aws_caller_identity.current.account_id}-session-manager-logs"
}



resource "aws_s3_bucket_server_side_encryption_configuration" "s3_cloudtrail_logs" {
  bucket = aws_s3_bucket.s3_cloudtrail_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}


resource "aws_s3_bucket_server_side_encryption_configuration" "s3_access_logs" {
  bucket = aws_s3_bucket.s3_access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3_vpc_flowlogs" {
  bucket = aws_s3_bucket.s3_vpc_flowlogs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3_session_manager_logs" {
  bucket = aws_s3_bucket.s3_session_manager_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}


resource "aws_s3_bucket_ownership_controls" "s3_access_logs" {
  bucket = aws_s3_bucket.s3_access_logs.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}



# Grant S3 log delivery service access via bucket policy
resource "aws_s3_bucket_policy" "s3_access_logs" {
  bucket = aws_s3_bucket.s3_access_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ServerAccessLogsPolicy"
        Effect = "Allow"
        Principal = {
          Service = "logging.s3.amazonaws.com"
        }
        Action = [
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.s3_access_logs.arn}/*"
      }
    ]
  })
}

resource "aws_s3_bucket_ownership_controls" "s3_cloudtrail_logs" {
  bucket = aws_s3_bucket.s3_cloudtrail_logs.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "s3_cloudtrail_logs" {
  bucket = aws_s3_bucket.s3_cloudtrail_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable access logging to the S3 access logs bucket
resource "aws_s3_bucket_logging" "s3_cloudtrail_logs" {
  bucket = aws_s3_bucket.s3_cloudtrail_logs.id

  target_bucket = aws_s3_bucket.s3_access_logs.id
  target_prefix = "s3-cloudtrail-logs/"
}

# Bucket policy for CloudTrail
resource "aws_s3_bucket_policy" "s3_cloudtrail_logs" {
  bucket = aws_s3_bucket.s3_cloudtrail_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.s3_cloudtrail_logs.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.s3_cloudtrail_logs.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_ownership_controls" "s3_vpc_flowlogs" {
  bucket = aws_s3_bucket.s3_vpc_flowlogs.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "s3_vpc_flowlogs" {
  bucket = aws_s3_bucket.s3_vpc_flowlogs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


resource "aws_s3_bucket_ownership_controls" "s3_session_manager_logs" {
  bucket = aws_s3_bucket.s3_session_manager_logs.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "s3_session_manager_logs" {
  bucket = aws_s3_bucket.s3_session_manager_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "s3_session_manager_logs" {
  bucket = aws_s3_bucket.s3_session_manager_logs.id

  target_bucket = aws_s3_bucket.s3_access_logs.id
  target_prefix = "s3-session-manager-logs/"
}

# IR Artifacts bucket
resource "aws_s3_bucket" "s3_ir_artifact_bucket" {
  bucket = "${data.aws_caller_identity.current.account_id}-ir-artifacts"

  object_lock_enabled = true

#   lifecycle {
#     prevent_destroy = true
#   }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3_ir_artifact_bucket" {
  bucket = aws_s3_bucket.s3_ir_artifact_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "s3_ir_artifact_bucket" {
  bucket = aws_s3_bucket.s3_ir_artifact_bucket.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "s3_ir_artifact_bucket" {
  bucket = aws_s3_bucket.s3_ir_artifact_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "s3_ir_artifact_bucket" {
  bucket = aws_s3_bucket.s3_ir_artifact_bucket.id

  target_bucket = aws_s3_bucket.s3_access_logs.id
  target_prefix = "s3-ir-artifacts/"
}

resource "aws_s3_bucket_lifecycle_configuration" "s3_ir_artifact_bucket" {
  bucket = aws_s3_bucket.s3_ir_artifact_bucket.id

  rule {
    id     = "ArchiveAfter395Days"
    status = "Enabled"

    transition {
      days          = 395
      storage_class = "GLACIER"
    }

    expiration {
      days = 2555
    }
  }
}

resource "aws_s3_bucket_object_lock_configuration" "s3_ir_artifact_bucket" {
  bucket = aws_s3_bucket.s3_ir_artifact_bucket.id

  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = var.ObjectLockRetentionPeriod
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}