#!/bin/env python3
import boto3
import requests
import os
import dotenv
from datetime import datetime, timedelta, timezone  # noqa: F401

dotenv.load_dotenv()
apikey = os.getenv("APIKEY")
base_url = os.getenv("BASEURL")
sns_topic_arn = os.getenv("SNSTOPICARN")
number = os.getenv("NUMBER")
client = boto3.client("sns")


def todays_date():
    utc_now = datetime.now(timezone.utc)
    central_time = utc_now - timedelta(hours=6)
    return f"{central_time.year}-{central_time.month:02}-{central_time.day:02}"
    # return "2025-01-07"


def get_the_days_game():
    url = f"{base_url}{todays_date()}?key={apikey}"
    try:
        response = requests.get(url)
        response.raise_for_status()  # Raise an error for bad HTTP responses
        return response.json()  # Return the JSON data
    except requests.exceptions.RequestException as e:
        print("Error fetching data:", str(e))  # Updated error message
        return False


def process_data():
    data = get_the_days_game()
    message = []
    if not data:
        # print("Cannot fetch data")
        return "cannot fetch data"
    else:
        for game in data:
            status = game.get("Status", "Unknown")
            away_team = game.get("AwayTeam", "Unknown")
            home_team = game.get("HomeTeam", "Unknown")
            final_score = (
                f"{game.get('AwayTeamScore', 'N/A')}"
                f"-{game.get('HomeTeamScore', 'N/A')}"
            )
            start_time = game.get("DateTime", "Unknown")
            channel = game.get("Channel", "Unknown")
            # Format quarters
            quarters = game.get("Quarters", [])
            quarter_scores = (
                ', '.join([
                    f"Q{q['Number']}: {q.get('AwayScore', 'N/A')}"
                    f"-{q.get('HomeScore', 'N/A')}" for q in quarters
                ])
            )

            if status == "Final":
                detail = (
                    f"Game Status: {status}\n"
                    f"{away_team} vs {home_team}\n"
                    f"Final Score: {final_score}\n"
                    f"Start Time: {start_time}\n"
                    f"Channel: {channel}\n"
                    f"Quarter Scores: {quarter_scores}\n"
                )
                # print(detail)
                message.append(detail)
            elif status == "InProgress":
                last_play = game.get("LastPlay", "N/A")
                detail = (
                    f"Game Status: {status}\n"
                    f"{away_team} vs {home_team}\n"
                    f"Current Score: {final_score}\n"
                    f"Last Play: {last_play}\n"
                    f"Channel: {channel}\n"
                )
                # print(detail)
                message.append(detail)
            else:
                detail = (
                    f"Game Status: {status}\n"
                    f"{away_team} vs {home_team}\n"
                    f"Start Time: {start_time}\n"
                    f"Channel: {channel}\n"
                )
                # print(detail)
                message.append(detail)
    return message


def publish_to_sns():
    data = process_data()
    # print(data)
    message = "The Game for today are:\n"
    for game in data:
        message = f"{message}{game}\n"
        # print(message)
    try:
        # print(message)
        client.publish(
            Message=message,
            TopicArn=sns_topic_arn,
            Subject="NBA Game Updates",
        )
        print("Message published to SNS successfully.")
    except Exception as e:
        print(f"Error publishing to SNS: {e}")
        return {"statusCode": 500, "body": "Error publishing to SNS"}

    return {"statusCode": 200, "body": "Data processed and sent to SNS"}


def lambda_handler(event, context):
    publish_to_sns()
