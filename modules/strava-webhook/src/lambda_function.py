import json
import boto3
import os
import urllib3
import time
from decimal import Decimal
from botocore.exceptions import ClientError

# Inicjalizacja klientów AWS poza handlerem (cold start)
sns_client = boto3.client('sns')
dynamodb = boto3.resource('dynamodb')
secrets_client = boto3.client('secretsmanager')
http = urllib3.PoolManager()

TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN')
TABLE_NAME = os.environ.get('DYNAMODB_TABLE_NAME', 'StravaActivities')
SECRET_NAME = os.environ.get('SECRET_NAME')

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
            
            table = dynamodb.Table(TABLE_NAME)
            pk = f"USER#{athlete_id}"
            sk = f"ACTIVITY#{activity_id}"
            
            # --- ZABEZPIECZENIE PRZED DUPLIKATAMI (IDEMPOTENCY) ---
            # Wrzucamy najpierw lekki rekord blokady. Jeśli klucz istnieje, DynamoDB rzuci wyjątek.
            try:
                table.put_item(
                    Item={
                        'pk': pk,
                        'sk': sk,
                        'timestamp': int(time.time()),
                        'status': 'PROCESSING'
                    },
                    ConditionExpression="attribute_not_exists(pk) AND attribute_not_exists(sk)"
                )
                print(f"Zablokowano ID aktywności: {activity_id}. Rozpoczynam przetwarzanie...")
            except ClientError as e:
                if e.response['Error']['Code'] == 'ConditionalCheckFailedException':
                    print(f"Ignoruję duplikat! Aktywność {activity_id} jest już procesowana lub została zapisana.")
                    # Zwracamy 200 OK, żeby uciszyć ponawiającą żądania Stravę
                    return {'statusCode': 200, 'body': 'OK'}
                else:
                    print(f"Błąd bazy danych przy weryfikacji duplikatu: {str(e)}")
                    raise e

            # --- PROCESOWANIE WŁAŚCIWE ---
            try:
                token = get_new_access_token()
                full_details = get_detailed_activity(activity_id, token)
                item_to_save = json.loads(json.dumps(full_details), parse_float=Decimal)
                
                # Aktualizujemy wcześniej utworzony rekord o pełne dane z API
                table.update_item(
                    Key={'pk': pk, 'sk': sk},
                    UpdateExpression="SET raw_data = :rd, #st = :status",
                    ExpressionAttributeNames={'#st': 'status'},
                    ExpressionAttributeValues={
                        ':rd': item_to_save,
                        ':status': 'COMPLETED'
                    }
                )
                
                # --- NOTIFICATION LOGIC ---
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

            except Exception as e:
                print(f"Error processing Strava notification: {str(e)}")
                # W przypadku wtopy usuwamy blokadę, żeby system mógł ponowić próbę przy następnym evencie
                try:
                    table.delete_item(Key={'pk': pk, 'sk': sk})
                except Exception as del_err:
                    print(f"Nie udało się zwolnić blokady w DynamoDB: {str(del_err)}")
                return {'statusCode': 500, 'body': 'Internal Server Error'}

    return {'statusCode': 200, 'body': 'OK'}