import type { SQSHandler } from "aws-lambda";
import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";

const s3 = new S3Client({});
const BUCKET = process.env.REPORTS_BUCKET!;

export const handler: SQSHandler = async (event) => {
  const written: string[] = [];

  for (const record of event.Records) {
    const now = new Date();
    const datePrefix = [
      now.getUTCFullYear(),
      String(now.getUTCMonth() + 1).padStart(2, "0"),
      String(now.getUTCDate()).padStart(2, "0"),
    ].join("/");
    const key = `reports/${datePrefix}/${record.messageId}.json`;

    await s3.send(
      new PutObjectCommand({
        Bucket: BUCKET,
        Key: key,
        Body: JSON.stringify({ messageId: record.messageId, body: record.body }),
        ContentType: "application/json",
      })
    );
    written.push(key);
  }

  console.log(`wrote ${written.length} object(s) to ${BUCKET}: ${JSON.stringify(written)}`);
};
