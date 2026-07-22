import json
import boto3
import os
import urllib3
import time
from decimal import Decimal

# Inicjalizacja klientów AWS poza handlerem (cold start)
sns_client = boto3.client('sns')
dynamodb = boto3.resource('dynamodb')
secrets_client = boto3.client('secretsmanager')
http = urllib3.PoolManager()

TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN')
TABLE_NAME = os.environ.get('DYNAMODB_TABLE_NAME', 'StravaActivities')
SECRET_NAME = os.environ.get('SECRET_NAME')
VERIFY_TOKEN = os.environ.get('VERIFY_TOKEN')

# Cache sekretu w pamięci procesu – pobieramy RAZ z Secrets Manager, potem trzymamy w RAM
_cached_secrets = None

def get_strava_credentials():
    """Pobiera dane uwierzytelniające Stravy z AWS Secrets Manager z cache'owaniem."""
    global _cached_secrets
    if _cached_secrets is None:
        resp = secrets_client.get_secret_value(SecretId=SECRET_NAME)
        _cached_secrets = json.loads(resp['SecretString'])
    return _cached_secrets

def update_refresh_token(new_token):
    """Aktualizuje refresh token w Secrets Manager po rotacji przez Stravę."""
    global _cached_secrets
    secrets_client.update_secret(
        SecretId=SECRET_NAME,
        SecretString=json.dumps({
            'STRAVA_CLIENT_ID': _cached_secrets['STRAVA_CLIENT_ID'],
            'STRAVA_CLIENT_SECRET': _cached_secrets['STRAVA_CLIENT_SECRET'],
            'STRAVA_REFRESH_TOKEN': new_token
        })
    )
    _cached_secrets['STRAVA_REFRESH_TOKEN'] = new_token

def get_new_access_token():
    creds = get_strava_credentials()
    url = "https://www.strava.com/oauth/token"
    data = {
        'client_id': creds['STRAVA_CLIENT_ID'],
        'client_secret': creds['STRAVA_CLIENT_SECRET'],
        'refresh_token': creds['STRAVA_REFRESH_TOKEN'],
        'grant_type': 'refresh_token'
    }
    encoded_data = json.dumps(data).encode('utf-8')
    resp = http.request('POST', url, body=encoded_data, headers={'Content-Type': 'application/json'}, timeout=3.0)
    if resp.status != 200:
        raise Exception(f"Failed to refresh token: {resp.data.decode('utf-8')}")
    
    token_data = json.loads(resp.data.decode('utf-8'))
    
    # Strava rotuje refresh token – każda odpowiedź zawiera nowy
    if 'refresh_token' in token_data:
        update_refresh_token(token_data['refresh_token'])
    
    return token_data.get('access_token')

def get_detailed_activity(activity_id, access_token):
    url = f"https://www.strava.com/api/v3/activities/{activity_id}"
    headers = {'Authorization': f'Bearer {access_token}'}
    resp = http.request('GET', url, headers=headers, timeout=4.0)
    if resp.status != 200:
        raise Exception(f"Failed to fetch activity details: {resp.data.decode('utf-8')}")
    return json.loads(resp.data.decode('utf-8'))

def lambda_handler(event, context):
    # 1. Handle Webhook Subscription Verification (GET)
    query_params = event.get('queryStringParameters') or {}
    if "hub.challenge" in query_params:
        print("Webhook verification challenge received.")

        if query_params.get('hub.verify_token') != VERIFY_TOKEN:
            print(f"Invalid verify_token! Got {query_params.get('hub.verify_token')}")
            return {'statusCode': 403, 'body': 'Forbidden'}
        return {
            'statusCode': 200,
            'body': json.dumps({"hub.challenge": query_params.get('hub.challenge')})
        }

    # 2. Process Incoming Activity Notification (POST)
    if event.get('body'):
        body = json.loads(event['body'])
        
        if body.get('object_type') == 'activity' and body.get('aspect_type') == 'create':
            activity_id = body.get('object_id')
            athlete_id = body.get('owner_id')

            if not activity_id or not athlete_id:
                print("Missing required fields in webhook payload")
                return {'statusCode': 400, 'body': 'Bad Request: missing object_id or owner_id'}

            try:
                int(activity_id)
            except (ValueError, TypeError):
                print(f"Invalid object_id format: {activity_id}")
                return{'statusCode': 400, 'body': 'Bad Request: invalid object_id'}

            try:
                int(athlete_id)
            except (ValueError, TypeError):
                print(f"Invalid owner_id format: {athlete_id}")
                return{'statusCode': 400, 'body': 'Bad Request: invalid owner_id'}
            
            # ---- SPRAWDŹ W API STRAVY PRZED ZAPISEM DO DB ----
            try:
                token = get_new_access_token()
                full_details = get_detailed_activity(activity_id, token)
            except Exception as e:
                print(f"Failed to fetch activity from Strava API: {str(e)}")
                return {'statusCode': 404, 'body': 'Activity not found or API Error'}

            # ---- SPRAWDŹ DUPLIKAT + ZAPISZ ----
            table = dynamodb.Table(TABLE_NAME)
            pk = f"USER#{athlete_id}"
            sk = f"ACTIVITY#{activity_id}"

            existing = table.get_item(Key={'pk': pk, 'sk': sk})
            if 'Item' in existing:
                print(f"Activity {activity_id} already processed - skipping duplicate")
                return {'statusCode': 200, 'body': 'OK'}

            item_to_save = json.loads(json.dumps(full_details), parse_float=Decimal)
            table.put_item(
                Item={
                    'pk': pk,
                    'sk': sk,
                    'raw_data': item_to_save,
                    'timestamp': int(time.time()),
                    'status': 'COMPLETED'
                }
            )

            # ---- SEND NOTIFICATION ----
            name = full_details.get('name', 'Unknown Activity')
            distance_km = full_details.get('distance', 0) / 1000
            duration_min = full_details.get('moving_time', 0) // 60
            heart_rate = full_details.get('average_heartrate', 'N/A')
            elevation = full_details.get('total_elevation_gain', 0)

            email_message = (
                f"New Activity Logged: {name}\n"
                f"----------------------------------\n"
                f"Distance: {distance_km:.2f} km\n"
                f"Duration: {duration_min} min\n"
                f"Avg HR: {heart_rate} bpm\n"
                f"Elevation Gain: {elevation} m\n"
                f"----------------------------------\n"
                f"Strava Link: https://www.strava.com/activities/{activity_id}"
            )

            sns_client.publish(
                TopicArn=TOPIC_ARN,
                Message=email_message,
                Subject=f"Strava: {name}"
            )
            print(f"Successfully processed activity {activity_id}")

    return {'statusCode': 200, 'body': 'OK'}