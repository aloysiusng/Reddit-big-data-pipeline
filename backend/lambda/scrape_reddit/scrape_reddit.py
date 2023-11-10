import json
import os
from datetime import datetime, timedelta

import boto3
import praw

s3 = boto3.client("s3")
bucket_name = os.environ["S3_BUCKET_NAME"]
secrets_manager_client = boto3.client("secretsmanager")
QUERY = "israel palestine"
# subreddits to check based on checking reddit
SUBREDDITS = ["Palestine", "Israel", "IsraelPalestine", "worldnews", "all"]


def getPRAWClient():
    secret = secrets_manager_client.get_secret_value(SecretId="reddit")
    secret = json.loads(secret["SecretString"])
    return praw.Reddit(
        client_id=secret["client_id"],
        client_secret=secret["client_secret"],
        password=secret["password"],
        username=secret["username"],
        user_agent=secret["user_agent"],
    )


def parse_reddit_post(post):
    return {
        "post_id": str(post.id),
        "post_date": str(datetime.fromtimestamp(post.created_utc)),
        "post_title": str(post.title),
        "post_content": str(post.selftext),
        "post_username": str(post.author),
        "post_comment_count": int(post.num_comments),
        "post_score": int(post.score),
        "post_subreddit": str(post.subreddit),
    }


def parse_reddit_comment(post, comment):
    return {
        "comment_id": str(comment.id),
        "comment_date": str(datetime.fromtimestamp(comment.created_utc)),
        "comment_content": str(comment.body),
        "comment_username": str(comment.author.name),
        "comment_score": int(comment.score),
        "post_id": str(post.id),
        "parent_id": str(comment.parent_id),
    }


def is_S3_empty():
    results = s3.list_objects(Bucket=bucket_name, Prefix="input/")
    return "Contents" not in results.keys()


def scrape_reddit(
    reddit_client, subreddit_name, query, posts, comments, errors, yesterday
):
    for post in reddit_client.subreddit(subreddit_name).search(
        query=query, sort="new", time_filter="all"
    ):
        # skips if post is older than yesterday
        if datetime.fromtimestamp(post.created_utc) < yesterday:
            continue
        try:
            posts.append(parse_reddit_post(post))
            # ignore those posts with no comments
            if post.num_comments > 0:
                submission = reddit_client.submission(id=post.id)
                submission.comments.replace_more(limit=None)
                for comment in submission.comments.list():
                    # skip if comment is from automoderator
                    if str(comment.author) == "AutoModerator":
                        continue
                    comments.append(parse_reddit_comment(post, comment))
        except Exception as e:
            # add to errors list
            errors.append({"id": str(post.id), "error": str(e)})
            continue


def lambda_handler(event, context):
    posts = []
    comments = []
    errors = []
    reddit_client = getPRAWClient()
    is_first_run = is_S3_empty()
    now = datetime.utcnow()
    now_date_string = now.strftime("%Y/%m/%d")
    yesterday = (
        now - timedelta(days=365)
        if is_first_run
        else now - timedelta(days=1, minutes=10)
    )
    for subreddit in SUBREDDITS:
        scrape_reddit(
            reddit_client, subreddit, QUERY, posts, comments, errors, yesterday
        )
    try:
        s3.put_object(
            Bucket=bucket_name,
            Key=f"input/scrape_reddit/{now_date_string}/posts.json",
            Body=json.dumps(posts),
            ContentType="application/json",
        )
        s3.put_object(
            Bucket=bucket_name,
            Key=f"input/scrape_reddit/{now_date_string}/comments.json",
            Body=json.dumps(comments),
            ContentType="application/json",
        )
        s3.put_object(
            Bucket=bucket_name,
            Key=f"error/scrape_reddit/{now_date_string}/errors.json",
            Body=json.dumps(errors),
            ContentType="application/json",
        )
    except Exception as e:
        print(e)
        return {"statusCode": 500, "body": str(e)}

    return {"statusCode": 200, "body": "Scrap success"}
