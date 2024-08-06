{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "secretsmanager:DescribeSecret",
                "secretsmanager:GetSecretValue"
            ],
            "Resource": ${jsonencode(resource_runtask_secrets)},
            "Effect": "Allow",
            "Sid": "SecretsManagerGet"
        },
        {
            "Action": "events:PutEvents",
            "Resource": "arn:${data_aws_partition}:events:${data_aws_region}:${data_aws_account_id}:event-bus/${var_event_bus_name}",
            "Effect": "Allow",
            "Sid": "EventBridgePut"
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