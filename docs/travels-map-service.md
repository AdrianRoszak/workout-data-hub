# Travels Map Service

A lightweight web map displaying hiking and trekking routes tracked via Strava, hosted under `travels.weirdo.codes`.

## Purpose

Show all Strava activities of type **Hike** (trekking, wycieczka piesza) on an interactive map. Users can browse past routes, see elevation profiles, and click individual tracks for details.

## Architecture

```
Route 53 (travels.weirdo.codes)
  → CloudFront (CDN + HTTPS)
    ├── /api/* → API Gateway → Lambda → DynamoDB
    └── /*     → S3 static website (Leaflet.js map)
```

### Components

| Component | Technology | Why |
|---|---|---|
| Frontend | Leaflet.js + vanilla JS | Lightweight (~42KB), no build step, OSM tiles (free) |
| Hosting | S3 static website + CloudFront | Cheap, fast, HTTPS via ACM |
| DNS | Route 53 | Already own `weirdo.codes` domain |
| API | API Gateway v2 (HTTP) + Lambda | Consistent with existing stack |
| Data | DynamoDB `StravaActivities` | Already populated, no migration needed |

### Data model (existing)

Activities are stored in DynamoDB with key structure:
- `pk`: `USER#{athlete_id}`
- `sk`: `ACTIVITY#{activity_id}`

Relevant fields inside `raw_data`:
- `type` – activity type (`Hike` for trekking)
- `map.summary_polyline` – encoded polyline of the route
- `start_latlng` / `end_latlng` – start/end coordinates
- `distance`, `total_elevation_gain`, `moving_time` – metrics
- `name`, `start_date_local` – display info
- `average_speed`, `max_speed`, `average_heartrate` – optional stats

### API design

| Method | Path | Description |
|---|---|---|
| `GET` | `/api/activities` | List all Hike activities (summary: id, name, date, distance, start coords) |
| `GET` | `/api/activities/{id}` | Full activity details including decoded polyline as GeoJSON |

**Response: `GET /api/activities`**
```json
{
  "activities": [
    {
      "id": "1234567890",
      "name": "Morning hike to the peak",
      "date": "2026-07-20T07:30:00Z",
      "distance_m": 12400,
      "elevation_m": 450,
      "duration_min": 180,
      "start_lat": 49.123,
      "start_lng": 20.456,
      "polyline": "encoded_string_here"
    }
  ]
}
```

### Frontend features (MVP)

1. Full-screen Leaflet map
2. All Hike tracks rendered as polylines, color-coded by date or elevation
3. Click on a track → popup with name, distance, elevation, duration
4. Map centered on Poland / Europe initially, auto-fits to tracks on load
5. Mobile-responsive

### Polyline decoding

Strava stores the route as an **encoded polyline** (Google's polyline encoding algorithm). The Lambda decodes it into `[[lat, lng], ...]` pairs before returning to the frontend. Leaflet renders this directly.

## Implementation plan

1. Create `modules/travels-map/` Terraform module
2. **Lambda** – query DynamoDB for Hike activities, decode polylines, return as GeoJSON
3. **API Gateway** – HTTP API with `/api/activities` and `/api/activities/{id}` routes
4. **S3 + CloudFront** – static hosting for the Leaflet frontend
5. **Route 53** – `travels.weirdo.codes` A record → CloudFront
6. **ACM** – TLS certificate for the domain
7. **Frontend HTML/JS** – single-page Leaflet map consuming the API

## Future improvements

- Filter by date range
- Elevation profile on click (Chart.js overlay)
- Photos from Strava activities shown on markers
- GPX export
- Heatmap layer for all tracks combined