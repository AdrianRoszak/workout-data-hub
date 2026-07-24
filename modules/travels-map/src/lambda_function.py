import json
import os
import boto3
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')

TABLE_NAME = os.environ.get('DYNAMODB_TABLE_NAME', 'StravaActivities')
ATHLETE_ID = os.environ.get('ATHLETE_ID')


def decode_polyline(encoded, precision=5):
    """
    Decode a Google-encoded polyline string into a list of [lat, lng] pairs.
    Precision=5 is Strava's default (1e5 scale).
    """
    if not encoded:
        return []

    polyline_chars = list(encoded)
    index = 0
    lat = 0
    lng = 0
    coordinates = []

    while index < len(polyline_chars):
        result = 0
        shift = 0

        while index < len(polyline_chars):
            byte = ord(polyline_chars[index]) - 63
            index += 1
            result |= (byte & 0x1F) << shift
            shift += 5
            if byte < 0x20:
                break

        dlat = ~(result >> 1) if (result & 1) else (result >> 1)
        lat += dlat

        result = 0
        shift = 0

        while index < len(polyline_chars):
            byte = ord(polyline_chars[index]) - 63
            index += 1
            result |= (byte & 0x1F) << shift
            shift += 5
            if byte < 0x20:
                break

        dlng = ~(result >> 1) if (result & 1) else (result >> 1)
        lng += dlng

        coordinates.append([lat / (10 ** precision), lng / (10 ** precision)])

    return coordinates


def build_activity_summary(item):
    """Extract summary fields from a DynamoDB item and decode the polyline."""
    raw = item.get('raw_data', {})

    polyline_encoded = ''
    if isinstance(raw, dict):
        map_data = raw.get('map', {})
        if isinstance(map_data, dict):
            polyline_encoded = map_data.get('summary_polyline', '')

    activity_id = (item.get('sk', '') or '').replace('ACTIVITY#', '')
    start_latlng = raw.get('start_latlng', []) if isinstance(raw, dict) else []
    start_lat = start_latlng[0] if isinstance(start_latlng, list) and len(start_latlng) >= 2 else None
    start_lng = start_latlng[1] if isinstance(start_latlng, list) and len(start_latlng) >= 2 else None

    return {
        'id': activity_id,
        'name': raw.get('name', 'Unknown') if isinstance(raw, dict) else 'Unknown',
        'date': raw.get('start_date_local', '') if isinstance(raw, dict) else '',
        'distance_m': float(raw.get('distance', 0)) if isinstance(raw, dict) else 0,
        'elevation_m': float(raw.get('total_elevation_gain', 0)) if isinstance(raw, dict) else 0,
        'duration_min': int(raw.get('moving_time', 0) // 60) if isinstance(raw, dict) else 0,
        'start_lat': float(start_lat) if start_lat is not None else None,
        'start_lng': float(start_lng) if start_lng is not None else None,
        'polyline': decode_polyline(polyline_encoded),
    }


def build_activity_detail(item):
    """Extract full activity details with decoded polyline as GeoJSON."""
    raw = item.get('raw_data', {})
    if not isinstance(raw, dict):
        raw = {}

    polyline_encoded = ''
    map_data = raw.get('map', {})
    if isinstance(map_data, dict):
        polyline_encoded = map_data.get('summary_polyline', '')

    activity_id = (item.get('sk', '') or '').replace('ACTIVITY#', '')
    coordinates = decode_polyline(polyline_encoded)

    geojson = None
    if coordinates:
        geojson = {
            'type': 'LineString',
            'coordinates': [[lng, lat] for lat, lng in coordinates],
        }

    return {
        'id': activity_id,
        'name': raw.get('name', 'Unknown'),
        'type': raw.get('type', ''),
        'date': raw.get('start_date_local', ''),
        'distance_m': float(raw.get('distance', 0)),
        'elevation_m': float(raw.get('total_elevation_gain', 0)),
        'duration_min': int(raw.get('moving_time', 0) // 60),
        'average_speed_ms': float(raw.get('average_speed', 0)),
        'max_speed_ms': float(raw.get('max_speed', 0)),
        'average_heartrate': float(raw.get('average_heartrate', 0)) if raw.get('average_heartrate') else None,
        'start_latlng': raw.get('start_latlng', []),
        'end_latlng': raw.get('end_latlng', []),
        'geojson': geojson,
    }


def lambda_handler(event, context):
    table = dynamodb.Table(TABLE_NAME)
    pk = f'USER#{ATHLETE_ID}'

    # Route: GET /api/activities/{id}
    path_params = event.get('pathParameters') or {}
    activity_id = path_params.get('id')

    if activity_id:
        sk = f'ACTIVITY#{activity_id}'
        resp = table.get_item(Key={'pk': pk, 'sk': sk})
        item = resp.get('Item')

        if not item:
            return {
                'statusCode': 404,
                'headers': {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
                'body': json.dumps({'error': 'Activity not found'}),
            }

        raw = item.get('raw_data', {})
        if isinstance(raw, dict) and raw.get('type') != 'Hike':
            return {
                'statusCode': 404,
                'headers': {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
                'body': json.dumps({'error': 'Activity not found'}),
            }

        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
            'body': json.dumps(build_activity_detail(item), default=str),
        }

    # Route: GET /api/activities
    resp = table.query(
        KeyConditionExpression=boto3.dynamodb.conditions.Key('pk').eq(pk),
    )

    items = resp.get('Items', [])
    hike_activities = [
        item for item in items
        if isinstance(item.get('raw_data', {}), dict) and item.get('raw_data', {}).get('type') == 'Hike'
    ]

    summaries = [build_activity_summary(item) for item in hike_activities]
    summaries.sort(key=lambda a: a.get('date', ''), reverse=True)

    return {
        'statusCode': 200,
        'headers': {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
        'body': json.dumps({'activities': summaries}, default=str),
    }