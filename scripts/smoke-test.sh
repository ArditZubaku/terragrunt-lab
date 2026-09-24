#!/usr/bin/env bash
set -euo pipefail

queue_name=$1
bucket_name=$2
endpoint=http://localhost:4566

queue_url=$(aws --endpoint-url "$endpoint" sqs get-queue-url --queue-name "$queue_name" --query QueueUrl --output text)

aws --endpoint-url "$endpoint" sqs send-message \
  --queue-url "$queue_url" \
  --message-body "{\"hello\":\"terragrunt\",\"ts\":\"$(date -u +%FT%TZ)\"}" \
  > /dev/null

echo "sent message to $queue_name, waiting for ingest-lambda..."
sleep 6

echo "objects in s3://$bucket_name/reports/:"
aws --endpoint-url "$endpoint" s3 ls "s3://$bucket_name/reports/" --recursive
