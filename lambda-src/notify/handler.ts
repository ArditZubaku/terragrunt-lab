import type { S3Handler } from "aws-lambda";

export const handler: S3Handler = async (event) => {
  for (const record of event.Records) {
    const { bucket, object } = record.s3;
    console.log(`[notify] new object s3://${bucket.name}/${object.key} (${object.size} bytes)`);
  }
};
