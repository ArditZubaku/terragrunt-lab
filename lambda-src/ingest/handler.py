import json
import os
from datetime import datetime, timezone

import boto3

s3 = boto3.client("s3")
BUCKET = os.environ["REPORTS_BUCKET"]


def handler(event, context):
    written = []
    for record in event.get("Records", []):
        message_id = record["messageId"]
        key = f"reports/{datetime.now(timezone.utc):%Y/%m/%d}/{message_id}.json"
        s3.put_object(
            Bucket=BUCKET,
            Key=key,
            Body=json.dumps({"messageId": message_id, "body": record["body"]}).encode(),
            ContentType="application/json",
        )
        written.append(key)

    print(f"wrote {len(written)} object(s) to {BUCKET}: {written}")
    return {"written": written}
