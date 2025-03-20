{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "secretsmanager:DescribeSecret",
                "secretsmanager:GetSecretValue"
            ],
            "Resource": ${jsonencode(github_api_token_arn)},
            "Effect": "Allow",
            "Sid": "SecretsManagerGet"
        }
    ]
}
