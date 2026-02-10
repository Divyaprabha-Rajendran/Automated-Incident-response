# # ==============================================================================
# # DATA SOURCES
# # ==============================================================================
# data "aws_caller_identity" "current_identity" {}
# data "aws_partition" "current_partition" {}
# data "aws_region" "current_region" {}

# # ==============================================================================
# # VARIABLES
# # ==============================================================================
# variable "org_id" {
#   description = "AWS Organization ID for cross-account access"
#   type        = string
# }

# variable "ir_artifact_bucket" {
#   description = "S3 bucket name for IR artifacts"
#   type        = string
# }

# # ==============================================================================
# # KMS KEY FOR SNS TOPIC ENCRYPTION
# # ==============================================================================
# # Encrypts messages in the security incident response SNS topic
# # Allows Lambda role to decrypt messages and external accounts in the org to publish
# resource "aws_kms_key" "sns_kms_key" {
#   description             = "KMS key used for the security incident response SNS topic"
#   enable_key_rotation     = true
#   multi_region            = false

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid    = "Enable Permissions for KMS Key usage"
#         Effect = "Allow"
#         Principal = {
#           AWS = aws_iam_role.sns_lambda_role.arn
#         }
#         Action = [
#           "kms:Encrypt",
#           "kms:Decrypt",
#           "kms:ReEncrypt*",
#           "kms:GenerateDataKey*",
#           "kms:DescribeKey"
#         ]
#         Resource = "*"
#       },
#       {
#         Sid    = "Enable KMS key management by the root account"
#         Effect = "Allow"
#         Principal = {
#           AWS = "arn:aws:iam::${data.aws_caller_identity.current_identity.account_id}:root"
#         }
#         Action   = "kms:*"
#         Resource = "*"
#       },
#       {
#         Sid    = "Enable KMS key access by the external account"
#         Effect = "Allow"
#         Principal = {
#           AWS = "*"
#         }
#         Action = [
#           "kms:GenerateDataKey*",
#           "kms:Decrypt"
#         ]
#         Resource = "*"
#         Condition = {
#           StringEquals = {
#             "aws:PrincipalOrgID" = var.org_id
#           }
#         }
#       }
#     ]
#   })

#   tags = {
#     Name = "SNS Security Incident KMS Key"
#   }
# }

# # ==============================================================================
# # IAM ROLE FOR SNS LAMBDA FUNCTION
# # ==============================================================================
# # Allows the Lambda function to write logs and trigger Step Functions
# resource "aws_iam_role" "sns_lambda_role" {
#   name = "SNSSecurityEventLambdaRole"
#   path = "/"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Principal = {
#           Service = "lambda.amazonaws.com"
#         }
#         Action = "sts:AssumeRole"
#       }
#     ]
#   })

#   inline_policy {
#     name = "SNSSecurityEventLambdaPolicy"

#     policy = jsonencode({
#       Version = "2012-10-17"
#       Statement = [
#         {
#           Effect = "Allow"
#           Action = [
#             "logs:CreateLogGroup",
#             "logs:CreateLogStream",
#             "logs:PutLogEvents"
#           ]
#           Resource = "arn:${data.aws_partition.current_partition.partition}:logs:*:*:*"
#         },
#         {
#           Effect = "Allow"
#           Action = [
#             "states:StartExecution"
#           ]
#           Resource = aws_sfn_state_machine.forensics_state_machine.arn
#         }
#       ]
#     })
#   }

#   tags = {
#     Name = "SNS Lambda Role"
#   }
# }

# # ==============================================================================
# # LAMBDA FUNCTION - TRIGGER IR STEP FUNCTION
# # ==============================================================================
# # Receives SNS notifications about security incidents and triggers the
# # forensics Step Function state machine with incident details
# resource "aws_lambda_function" "trigger_ir_stepfunction" {
#   filename      = "lambda_trigger_ir.zip"
#   function_name = "LambdaTriggerIRStepFunction"
#   role          = aws_iam_role.sns_lambda_role.arn
#   handler       = "index.lambda_handler"
#   runtime       = "python3.9"
#   timeout       = 60
#   memory_size   = 128
#   description   = "Trigger the statemachine to perform IR"

#   environment {
#     variables = {
#       Partition    = data.aws_partition.current_partition.partition
#       AccountId    = data.aws_caller_identity.current_identity.account_id
#       MasterRegion = data.aws_region.current_region.name
#       StepFunction = aws_sfn_state_machine.forensics_state_machine.arn
#     }
#   }

#   tags = {
#     Name = "IR StepFunction Trigger"
#   }
# }

# # Create the Lambda deployment package
# data "archive_file" "lambda_trigger_ir" {
#   type        = "zip"
#   output_path = "${path.module}/lambda_trigger_ir.zip"

#   source {
#     content = <<-EOT
#       import json,time
#       import boto3
#       import os
#       client = boto3.client('stepfunctions')
#       stepfunction = os.environ['StepFunction']
      
#       def generate_case_id(account,instance_id,region):
#           epoch_time = str(int(time.time()))
#           case_id = '-'.join([account,instance_id,region,epoch_time])
#           return case_id

#       def trigger_stepfunction(case_id, account, instance_id,region):
#           step_function_request = {   "CaseId": case_id,
#                                       "InstanceId": instance_id,
#                                       "Account": account,
#                                       "Region": region,
#                                       "RetainArtefacts": "true"
#                                   }
#           input = json.dumps(step_function_request)
#           response = client.start_execution(
#               stateMachineArn=stepfunction,
#               name='sf-forensics-'+case_id,
#               input=input
#           )
#           print(response)


#       def lambda_handler(event, context):
#           msg = json.loads(event['Records'][0]['Sns']['Message'])
#           account = msg['account']
#           instance_id = msg['instance_id']
#           region = msg['region']
#           case_id = generate_case_id(account, instance_id, region)
#           trigger_stepfunction(case_id , account, instance_id, region)
#     EOT
#     filename = "index.py"
#   }
# }

# # ==============================================================================
# # SNS TOPIC - SECURITY INCIDENT EVENTS
# # ==============================================================================
# # Central topic for receiving security incident notifications from across the org
# resource "aws_sns_topic" "security_incident_event_topic" {
#   name              = "security-incident-response-events"
#   display_name      = "security-incident-response-events"
#   kms_master_key_id = aws_kms_key.sns_kms_key.id

#   tags = {
#     Name = "Security Incident Response Events"
#   }
# }

# # ==============================================================================
# # SNS TOPIC SUBSCRIPTION - LAMBDA
# # ==============================================================================
# # Subscribes the Lambda function to the SNS topic
# resource "aws_sns_topic_subscription" "lambda_subscription" {
#   topic_arn = aws_sns_topic.security_incident_event_topic.arn
#   protocol  = "lambda"
#   endpoint  = aws_lambda_function.trigger_ir_stepfunction.arn
# }

# # ==============================================================================
# # LAMBDA PERMISSION - ALLOW SNS TO INVOKE
# # ==============================================================================
# # Grants SNS permission to invoke the Lambda function
# resource "aws_lambda_permission" "sns_invoke_lambda" {
#   statement_id  = "AllowExecutionFromSNS"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.trigger_ir_stepfunction.function_name
#   principal     = "sns.amazonaws.com"
#   source_arn    = aws_sns_topic.security_incident_event_topic.arn
# }

# # ==============================================================================
# # SNS TOPIC POLICY
# # ==============================================================================
# # Allows Lambda and accounts within the organization to publish to the topic
# resource "aws_sns_topic_policy" "security_incident_event_topic_policy" {
#   arn = aws_sns_topic.security_incident_event_topic.arn

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid    = "AllowServices"
#         Effect = "Allow"
#         Principal = {
#           Service = "lambda.amazonaws.com"
#         }
#         Action = "sns:Publish"
#         Resource = aws_sns_topic.security_incident_event_topic.arn
#       },
#       {
#         Sid    = "AllowAWSPublish"
#         Effect = "Allow"
#         Principal = {
#           AWS = "*"
#         }
#         Action   = "sns:Publish"
#         Resource = aws_sns_topic.security_incident_event_topic.arn
#         Condition = {
#           StringEquals = {
#             "aws:PrincipalOrgID" = var.org_id
#           }
#         }
#       }
#     ]
#   })
# }

# # ==============================================================================
# # KMS KEY FOR EBS SNAPSHOTS AND VOLUMES
# # ==============================================================================
# # Encrypts EBS snapshots and volumes created during forensic acquisition
# # Allows the Lambda role to create encrypted snapshots across accounts
# resource "aws_kms_key" "snapshot_key" {
#   description         = "Snapshot Automation KMS key for EBS Snapshots and Volumes in Security Account"
#   enable_key_rotation = true

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Id      = "key-default-1"
#     Statement = [
#       {
#         Sid    = "Allow administration of the key"
#         Effect = "Allow"
#         Principal = {
#           AWS = "arn:${data.aws_partition.current_partition.partition}:iam::${data.aws_caller_identity.current_identity.account_id}:root"
#         }
#         Action = [
#           "kms:GenerateRandom",
#           "kms:TagResource",
#           "kms:Create*",
#           "kms:List*",
#           "kms:Enable*",
#           "kms:Describe*",
#           "kms:Put*",
#           "kms:Update*",
#           "kms:Revoke*",
#           "kms:Disable*",
#           "kms:Get*",
#           "kms:Delete*",
#           "kms:CancelKeyDeletion",
#           "kms:ImportKeyMaterial",
#           "kms:UntagResource",
#           "kms:RetireGrant",
#           "kms:GenerateDataKeyWithoutPlaintext",
#           "kms:ScheduleKeyDeletion"
#         ]
#         Resource = "*"
#       },
#       {
#         Sid    = "Allow use of the key for copy snapshot"
#         Effect = "Allow"
#         Principal = {
#           AWS = aws_iam_role.lambda_role.arn
#         }
#         Action = [
#           "kms:Encrypt",
#           "kms:Decrypt",
#           "kms:ReEncrypt*",
#           "kms:GenerateDataKey*",
#           "kms:CreateGrant",
#           "kms:DescribeKey"
#         ]
#         Resource = "*"
#         Condition = {
#           StringEquals = {
#             "kms:ViaService" = "ec2.${data.aws_region.current_region.name}.amazonaws.com"
#             "kms:CallerAccount" = data.aws_caller_identity.current_identity.account_id
#           }
#           Bool = {
#             "kms:GrantIsForAWSResource" = "true"
#           }
#         }
#       },
#       {
#         Sid    = "Allow use of the key for creation of a volume from snapshot"
#         Effect = "Allow"
#         Principal = {
#           AWS = aws_iam_role.lambda_role.arn
#         }
#         Action = [
#           "kms:Encrypt",
#           "kms:Decrypt",
#           "kms:ReEncrypt*",
#           "kms:GenerateDataKey*",
#           "kms:DescribeKey"
#         ]
#         Resource = "*"
#       },
#       {
#         Sid    = "Allow attachment of persistent resources to support creation of a volume from snapshot"
#         Effect = "Allow"
#         Principal = {
#           AWS = aws_iam_role.lambda_role.arn
#         }
#         Action = [
#           "kms:CreateGrant",
#           "kms:ListGrants",
#           "kms:RevokeGrant"
#         ]
#         Resource = "*"
#         Condition = {
#           Bool = {
#             "kms:GrantIsForAWSResource" = "true"
#           }
#         }
#       }
#     ]
#   })

#   tags = {
#     Name = "Snapshot Automation KMS Key"
#   }

#   depends_on = [aws_iam_role.lambda_role]
# }

# # KMS Key Alias for easier reference
# resource "aws_kms_alias" "sec_ir_key_alias" {
#   name          = "alias/ir/sec"
#   target_key_id = aws_kms_key.snapshot_key.key_id
# }

# # ==============================================================================
# # IAM ROLE FOR SNAPSHOT AUTOMATION LAMBDA
# # ==============================================================================
# # Main role for Lambda functions that perform forensic snapshot acquisition
# # Allows cross-account snapshot copying, EC2 operations, and S3 access
# resource "aws_iam_role" "lambda_role" {
#   name = "SnapshotAutomationLambdaRole"
#   path = "/"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Principal = {
#           Service = "lambda.amazonaws.com"
#         }
#         Action = "sts:AssumeRole"
#       }
#     ]
#   })

#   inline_policy {
#     name = "SnapshotAutomation"

#     policy = jsonencode({
#       Version = "2012-10-17"
#       Statement = [
#         {
#           Effect = "Allow"
#           Action = "sts:AssumeRole"
#           Resource = "arn:${data.aws_partition.current_partition.partition}:iam::*:role/IRAutomation"
#         },
#         {
#           Effect = "Allow"
#           Action = [
#             "logs:CreateLogGroup",
#             "logs:CreateLogStream",
#             "logs:PutLogEvents"
#           ]
#           Resource = "arn:${data.aws_partition.current_partition.partition}:logs:*:*:*"
#         },
#         {
#           Effect = "Allow"
#           Action = [
#             "ec2:CreateVolume",
#             "ec2:CreateSnapshot",
#             "ec2:AttachVolume",
#             "ec2:DetachVolume",
#             "ec2:CreateTags",
#             "ec2:DescribeVolumes",
#             "ec2:DescribeVolumeStatus",
#             "ec2:DescribeVolumeAttribute",
#             "ec2:DescribeVolumesModifications",
#             "ec2:DescribeInstances",
#             "ec2:DescribeSnapshots",
#             "ec2:DescribeSecurityGroups",
#             "ec2:DescribeVpcs",
#             "ec2:DescribeSubnets",
#             "ec2:DescribeTags",
#             "ec2:CopySnapshot",
#             "ec2:RunInstances"
#           ]
#           Resource = "*"
#         },
#         {
#           Effect = "Allow"
#           Action = [
#             "ec2:TerminateInstances",
#             "ec2:DeleteVolume",
#             "ec2:DeleteSnapshot"
#           ]
#           Resource = "*"
#           Condition = {
#             StringEquals = {
#               "aws:ResourceTag/ir-acquisition" = "True"
#             }
#           }
#         },
#         {
#           Effect = "Allow"
#           Action = "iam:PassRole"
#           Resource = aws_iam_role.s3_copy_role.arn
#         },
#         {
#           Effect = "Allow"
#           Action = [
#             "s3:PutObject",
#             "s3:GetObject",
#             "s3:PutObjectAcl"
#           ]
#           Resource = "arn:${data.aws_partition.current_partition.partition}:s3:::${var.ir_artifact_bucket}/*"
#         },
#         {
#           Effect = "Allow"
#           Action = [
#             "kms:Decrypt",
#             "kms:CreateGrant"
#           ]
#           Resource = "*"
#         },
#         {
#           Effect = "Allow"
#           Action = [
#             "ssm:GetParameter",
#             "ssm:GetParameters",
#             "ssm:SendCommand",
#             "ssm:GetCommandInvocation"
#           ]
#           Resource = "*"
#         },
#         {
#           Effect = "Allow"
#           Action = "sqs:SendMessage"
#           Resource = "*"
#         }
#       ]
#     })
#   }

#   tags = {
#     Name = "Snapshot Automation Lambda Role"
#   }
# }

# # ==============================================================================
# # KMS POLICY ATTACHMENT FOR LAMBDA ROLE
# # ==============================================================================
# # Grants the Lambda role permissions to use the snapshot KMS key
# resource "aws_iam_role_policy" "kms_policy" {
#   name = "CFNUsers"
#   role = aws_iam_role.lambda_role.id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           "kms:Decrypt",
#           "kms:Encrypt",
#           "kms:ReEncrypt*",
#           "kms:DescribeKey",
#           "kms:CreateGrant",
#           "kms:ListGrants",
#           "kms:RevokeGrant",
#           "kms:GenerateDataKey*"
#         ]
#         Resource = aws_kms_key.snapshot_key.arn
#       }
#     ]
#   })

#   depends_on = [aws_kms_key.snapshot_key]
# }

# # ==============================================================================
# # IAM ROLE FOR S3 COPY INSTANCES
# # ==============================================================================
# # Used by EC2 instances to copy disk images (dd output) to S3
# # Instances use SSM Session Manager for secure access
# resource "aws_iam_role" "s3_copy_role" {
#   name                 = "SnapshotAutomationS3Copy"
#   path                 = "/"
#   max_session_duration = 43200  # 12 hours

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Principal = {
#           Service = "ec2.amazonaws.com"
#         }
#         Action = "sts:AssumeRole"
#       }
#     ]
#   })

#   inline_policy {
#     name = "CopySnapshotToS3"

#     policy = jsonencode({
#       Version = "2012-10-17"
#       Statement = [
#         {
#           Effect = "Allow"
#           Action = [
#             "s3:CreateMultipartUpload",
#             "s3:AbortMultipartUpload",
#             "s3:GetBucketLocation",
#             "s3:ListBucket",
#             "s3:ListBucketMultipartUploads",
#             "s3:PutObject",
#             "s3:PutObjectAcl",
#             "s3:HeadObject"
#           ]
#           Resource = [
#             "arn:${data.aws_partition.current_partition.partition}:s3:::${var.ir_artifact_bucket}/*",
#             "arn:${data.aws_partition.current_partition.partition}:s3:::${var.ir_artifact_bucket}"
#           ]
#         }
#       ]
#     })
#   }

#   tags = {
#     Name = "S3 Copy Role"
#   }
# }

# # Attach SSM managed policy for Session Manager access
# resource "aws_iam_role_policy_attachment" "s3_copy_role_ssm" {
#   role       = aws_iam_role.s3_copy_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
# }

# # ==============================================================================
# # INSTANCE PROFILE FOR S3 COPY ROLE
# # ==============================================================================
# # Instance profile to attach the S3 copy role to EC2 instances
# resource "aws_iam_instance_profile" "s3_copy_instance_profile" {
#   name = "S3CopyInstanceProfile"
#   path = "/"
#   role = aws_iam_role.s3_copy_role.name
# }