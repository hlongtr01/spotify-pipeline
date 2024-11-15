import requests
import boto3
import base64
import os
import pandas as pd
from datetime import datetime


AWS_ACCESS_KEY_ID = os.getenv('AWS_ACCESS_KEY_ID')
AWS_SECRET_ACCESS_KEY = os.getenv('AWS_SECRET_ACCESS_KEY')
AWS_SESSION_TOKEN = os.getenv('AWS_SESSION_TOKEN')
AWS_DEFAULT_REGION = os.getenv('AWS_DEFAULT_REGION')

S3_BUCKET = os.getenv('S3_BUCKET')
SPOTIFY_CLIENT_ID = os.getenv('SPOTIFY_CLIENT_ID')
SPOTIFY_CLIENT_SECRET = os.getenv('SPOTIFY_CLIENT_SECRET')

today_date = datetime.today().strftime('%Y-%m-%d')
file_name = f'{today_date}.csv'
file_path = f'/tmp/{file_name}'


def return_token():
    """
    Return API's access token
    """

    url = "https://accounts.spotify.com/api/token"
    auth_str = f"{SPOTIFY_CLIENT_ID}:{SPOTIFY_CLIENT_SECRET}"
    b64_auth_str = base64.b64encode(auth_str.encode()).decode()
    headers = {
        "Authorization": f"Basic {b64_auth_str}",
        "Content-Type": "application/x-www-form-urlencoded"
    }
    data = {"grant_type": "client_credentials"}
    response = requests.post(url, headers=headers, data=data)
    
    if response.status_code == 200:
        result = response.json()
        token = result.get("access_token")
        return token
    else:
        print(f"Failed to get access token. Status code: {response.status_code}")
        print(response.json())


def return_data():
    """
    Return Spotify data in json using the access token from return_token()
    """

    access_token = return_token()
    headers = {
        "Authorization": f"Bearer {access_token}"
    }
    playlist_id = '37i9dQZEVXbMDoHDwVN2tF' ## TOP 50 GLOBAL PLAYLIST
    url = f"https://api.spotify.com/v1/playlists/{playlist_id}/tracks"
    response = requests.get(url, headers=headers)

    if response.status_code == 200:
        json_data = response.json()
        return json_data
    else:
        print(f"Failed to access data. Status code {response.status_code}")


def extract_data():
    """
    Extract the required data from return_data()'s json
    """

    data = []
    rank = 1
    json_data = return_data()
    items = json_data['items']
    for item in items:
        track = item['track']
        duration_ms = track['duration_ms']
        duration_min = duration_ms // 60000
        duration_sec = (duration_ms % 60000) // 1000
        data.append({
            "rank": rank,
            "name": track['name'],
            "artist": track['artists'][0]['name'],
            "release_date": track['album']['release_date'],
            "duration": f"{duration_min}m{duration_sec}s",
            "duration_ms": duration_ms,
            "url": track['external_urls']['spotify']
        })
        rank = rank + 1
    return data


def s3_upload(api_data):
    """
    Initialize boto3 session to upload extracted data to S3 bucket
    """

    session = boto3.Session(
        aws_access_key_id = AWS_ACCESS_KEY_ID,
        aws_secret_access_key = AWS_SECRET_ACCESS_KEY,
        aws_session_token=AWS_SESSION_TOKEN,
        region_name = AWS_DEFAULT_REGION
    )
    s3_client = session.client('s3')
  
    try:
        df = pd.DataFrame(api_data)
        df.to_csv(file_path, index=False)
        s3_client.upload_file(file_path, S3_BUCKET, file_name)
        os.remove(file_path)
    except Exception as e:
        print(f"Error when uploading to S3: {e}")
        return False
    finally:
        print("Task executed successfully!")


def lambda_handler(event, context):
    try:
        data = extract_data()
        s3_upload(data)
    except Exception as e:
        print(f"Error when uploading to S3: {e}")