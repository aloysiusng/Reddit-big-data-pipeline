import sys
from datetime import datetime

import boto3
from awsglue.context import GlueContext
from awsglue.dynamicframe import DynamicFrame
from awsglue.job import Job
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql.functions import col, concat, lit

args = getResolvedOptions(sys.argv, ["JOB_NAME"])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args["JOB_NAME"], args)


posts = glueContext.create_dynamic_frame.from_catalog(
    database="social_media_glue_catalog_database",
    table_name="scrape_reddit_posts",
)
posts_df = posts.toDF()
# data cleaning =========================================================================================================
posts_df.dropDuplicates(["post_title", "partition_2", "partition_1", "partition_0"])
posts_df = posts_df.withColumn(
    "post_title_and_content",
    concat(
        lit("title: "),
        posts_df["post_title"],
        lit(" content: "),
        posts_df["post_content"],
    ),
)

#  sentiment analysis   =================================================================================================
sentiments = []
comprehend = boto3.client(service_name="comprehend", region_name="us-east-1")
post_title_and_content = posts_df.select("post_title_and_content").to_list()
# batch process
batches = [
    post_title_and_content[i : i + 25]
    for i in range(0, len(post_title_and_content), 25)
]
try:
    for i, batch in enumerate(batches):
        response = comprehend.batch_detect_sentiment(TextList=batch, LanguageCode="en")
        for res in response["ResultList"]:
            index = i * len(batch) + res["Index"]
            score = res["SentimentScore"]
            sentiments.append(
                {
                    "index": index,
                    "Neutral": score["Neutral"],
                    "Mixed": score["Mixed"],
                    "Negative": score["Negative"],
                    "Positive": score["Positive"],
                }
            )
    for key in sentiments[0].keys():
        posts_df = posts_df.withColumn(key, col(key))

except Exception as e:
    print(e)


dynamic_frame_write = DynamicFrame.fromDF(posts_df, glueContext, "dynamic_frame_write")

now = datetime.now()
year = now.year
month = now.month
day = now.day
output_s3_uri = f"s3://aloy-social-media-data-bucket/output/reddit_posts_sentiment/{year}/{month}/{day}/"

glueContext.write_dynamic_frame.from_options(
    frame=dynamic_frame_write,
    connection_type="s3",
    connection_options={"path": output_s3_uri},
    format="csv",
)

job.commit()