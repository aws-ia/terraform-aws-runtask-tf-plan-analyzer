{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "access-analyzer:ValidatePolicy"
            ],
            "Resource": "arn:${data_aws_partition}:access-analyzer:${data_aws_region}:${data_aws_account_id}:*",
            "Effect": "Allow",
            "Sid": "AccessAnalyzerOps"
        },
        {
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:${data_aws_partition}:logs:${data_aws_region}:${data_aws_account_id}:log-group:${local_log_group_name}/*",
            "Effect": "Allow",
            "Sid": "CloudWatchLogOps"
        },
        {
            "Action": [
                "xray:PutTraceSegments",
                "xray:PutTelemetryRecords"
            ],
            "Resource": "*",
            "Effect": "Allow",
            "Sid": "XRayTracing"
        }
    ]
}