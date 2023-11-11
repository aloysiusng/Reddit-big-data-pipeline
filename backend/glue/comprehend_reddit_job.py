import sys
from datetime import datetime

import boto3
from awsglue.context import GlueContext
from awsglue.dynamicframe import DynamicFrame
from awsglue.job import Job
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql.functions import concat, lit, monotonically_increasing_id

args = getResolvedOptions(sys.argv, ["JOB_NAME"])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args["JOB_NAME"], args)
max_text_size = 4500


# helper methods @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
# creating dynamic frames =================================================================================================
def create_DF(table_name, drop_duplicates_cols):
    df = glueContext.create_dynamic_frame.from_catalog(
        database="social_media_glue_catalog_database", table_name=table_name
    )
    df = df.toDF()
    df.dropDuplicates(drop_duplicates_cols)
    return df


# sentiment analysis   =================================================================================================
def comprehend_sentiment(comprehend, df, col_name_for_analysis):
    sentiments = []
    selected_col = df.select(col_name_for_analysis).rdd.flatMap(lambda x: x).collect()
    # batch process
    batches = [selected_col[i : i + 25] for i in range(0, len(selected_col), 25)]
    for i, batch in enumerate(batches):
        try:
            trimmed_batch = [text[:max_text_size] for text in batch]
            response = comprehend.batch_detect_sentiment(
                TextList=trimmed_batch, LanguageCode="en"
            )
            if response["ErrorList"]:
                print("errorlist ==============================")
                print(response["ErrorList"])

            for res in response["ResultList"]:
                index = i * len(batch) + res["Index"]
                sentiments.append(
                    {
                        "index": index,
                        "Neutral": res["SentimentScore"]["Neutral"],
                        "Mixed": res["SentimentScore"]["Mixed"],
                        "Negative": res["SentimentScore"]["Negative"],
                        "Positive": res["SentimentScore"]["Positive"],
                        "Sentiment": res["Sentiment"],
                    }
                )

        except Exception as e:
            print(f"Error processing batch {i}: {e}")

    return sorted(sentiments, key=lambda x: x["index"])


def combine_sentiment_with_df(df, sentiments_df):
    df = df.withColumn("index", monotonically_increasing_id())
    df.show()
    joined_df = df.join(sentiments_df, on="index", how="left")
    joined_df = joined_df.drop("index")
    joined_df.show()
    return joined_df


# script start @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
posts_df = create_DF(
    "scrape_reddit_posts", ["post_title", "partition_2", "partition_1", "partition_0"]
)
posts_df.show()
comments_df = create_DF(
    "scrape_reddit_comments",
    ["comment_content", "partition_2", "partition_1", "partition_0"],
)
# data processing =========================================================================================================
posts_df = posts_df.withColumn(
    "post_title_and_content",
    concat(
        lit("title: "),
        posts_df["post_title"],
        lit(" content: "),
        posts_df["post_content"],
    ),
)
# comprehend =========================================================================================================
comprehend = boto3.client(service_name="comprehend", region_name="us-east-1")

post_sentiments = comprehend_sentiment(comprehend, posts_df, "post_title_and_content")
comments_sentiments = comprehend_sentiment(comprehend, comments_df, "comment_content")
comprehend.close()

post_sentiments_df = spark.createDataFrame(post_sentiments)
posts_comprehended_df = combine_sentiment_with_df(posts_df, post_sentiments_df)

comments_sentiments_df = spark.createDataFrame(comments_sentiments)
comments_comprehended_df = combine_sentiment_with_df(
    comments_df, comments_sentiments_df
)

posts_comprehended_df = posts_comprehended_df.repartition(1)
post_dynamic_frame_write = DynamicFrame.fromDF(
    posts_comprehended_df, glueContext, "post_dynamic_frame_write"
)


comments_comprehended_df = comments_comprehended_df.repartition(1)
comment_dynamic_frame_write = DynamicFrame.fromDF(
    comments_comprehended_df, glueContext, "comment_dynamic_frame_write"
)

# combine ================================================================================================================
comments_comprehended_df = comments_comprehended_df.groupBy("post_id").agg(
    {"Positive": "avg", "Negative": "avg", "Neutral": "avg", "Mixed": "avg"}
)

comments_comprehended_df = (
    comments_comprehended_df.withColumnRenamed("avg(Positive)", "comments_avg_positive")
    .withColumnRenamed("avg(Negative)", "comments_avg_negative")
    .withColumnRenamed("avg(Neutral)", "comments_avg_neutral")
    .withColumnRenamed("avg(Mixed)", "comments_avg_mixed")
)

comments_comprehended_df = comments_comprehended_df.select(
    "post_id",
    "comments_avg_positive",
    "comments_avg_negative",
    "comments_avg_neutral",
    "comments_avg_mixed",
)

overall_sentiments_df = posts_comprehended_df.join(
    comments_comprehended_df, on="post_id", how="left"
)
overall_sentiments_df = overall_sentiments_df.repartition(1)
overall_dynamic_frame_write = DynamicFrame.fromDF(
    overall_sentiments_df, glueContext, "overall_dynamic_frame_write"
)

# output ================================================================================================================
now = datetime.now()
year = now.year
month = now.month
day = now.day
glueContext.write_dynamic_frame.from_options(
    frame=overall_dynamic_frame_write,
    connection_type="s3",
    connection_options={
        "path": f"s3://aloy-social-media-data-bucket/output/reddit_overall_sentiments/{year}/{month}/{day}/"
    },
    format="csv",
)

glueContext.write_dynamic_frame.from_options(
    frame=post_dynamic_frame_write,
    connection_type="s3",
    connection_options={
        "path": f"s3://aloy-social-media-data-bucket/output/reddit_comprehended_posts/{year}/{month}/{day}/"
    },
    format="csv",
)

glueContext.write_dynamic_frame.from_options(
    frame=comment_dynamic_frame_write,
    connection_type="s3",
    connection_options={
        "path": f"s3://aloy-social-media-data-bucket/output/reddit_comprehended_comments/{year}/{month}/{day}/"
    },
    format="csv",
)

job.commit()
