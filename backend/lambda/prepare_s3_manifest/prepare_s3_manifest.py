# following: https://docs.aws.amazon.com/quicksight/latest/user/supported-manifest-file-format.html
import json
import os
from collections import defaultdict
from datetime import datetime

import boto3

s3 = boto3.client("s3")
bucket_name = os.environ["S3_BUCKET_NAME"]


def lambda_handler(event, context):
    now = datetime.now()
    year = now.year
    month = now.month
    day = now.day

    # builder for manifest file
    manifest = defaultdict(list)
    URIPrefixes = {
        "URIPrefixes": [
            f"s3://{bucket_name}/output/reddit_overall_sentiments/{year}/{month}/{day}/",
            f"s3://{bucket_name}/output/reddit_comprehended_posts/{year}/{month}/{day}/",
            f"s3://{bucket_name}/output/reddit_comprehended_comments/{year}/{month}/{day}/",
        ]
    }
    
    manifest["fileLocations"] = [URIPrefixes]
    manifest["globalUploadSettings"] = {
        "format": "CSV",
        "delimiter": ",",
        "containsHeader": "true",
    }

    print(json.dumps(manifest, indent=4))

    # write manifest file to S3
    try:
        s3.put_object(
            Bucket=bucket_name,
            Key="manifests/reddit_manifest.json",
            Body=json.dumps(manifest, indent=4),
        )
    except Exception as e:
        print(e)
        return {"statusCode": 500, "body": "S3 manifest generation failed " + str(e)}
    return {"statusCode": 200, "body": "S3 manifest generation success"}
