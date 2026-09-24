def handler(event, context):
    records = event.get("Records", [])
    for record in records:
        bucket = record["s3"]["bucket"]["name"]
        key = record["s3"]["object"]["key"]
        size = record["s3"]["object"].get("size")
        print(f"[notify] new object s3://{bucket}/{key} ({size} bytes)")

    return {"received": len(records)}
