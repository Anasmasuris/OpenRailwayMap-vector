# Hmoe page
GET {{base_url}}/
HTTP 200
Content-Type: text/html
[Asserts]
body contains "<title>OpenRailwayMap</title>"

# News
GET {{base_url}}/news.html
HTTP 200
Content-Type: text/html
[Asserts]
body contains "<em class=\"flex-fill\">April 2025</em>"
header "X-Content-Hash" matches "^[0-9a-f]{40}$"

# Manifest
GET {{base_url}}/manifest.json
HTTP 200
Content-Type: application/json

# Proxy to tiles
GET {{base_url}}/speed
Referer: http://localhost:8000
HTTP 200
Content-Type: application/json

GET {{base_url}}/standard
Referer: http://localhost:8000
HTTP 200
Content-Type: application/json

GET {{base_url}}/speed
Referer: http://localhost:8000
HTTP 200
Content-Type: application/json

GET {{base_url}}/signals
Referer: http://localhost:8000
HTTP 200
Content-Type: application/json

GET {{base_url}}/electrification
Referer: http://localhost:8000
HTTP 200
Content-Type: application/json

# (local URLs)
GET {{base_url}}/signals_railway_signals/14/8803/5371
Referer: http://localhost:8000
HTTP 200
Content-Type: application/x-protobuf

GET {{base_url}}/signals_railway_signals/18/140807/85974
Referer: http://localhost:8000
HTTP 204

# Proxy to API, cannot proxy
GET {{base_url}}/api/test
HTTP 502

# Proxy to sprites
GET {{base_url}}/sprite/symbols.json
HTTP 200
Content-Type: application/json

GET {{base_url}}/sprite/symbols.png
HTTP 200

# Proxy to SDF sprites
GET {{base_url}}/sdf_sprite/symbols.json
HTTP 200
Content-Type: application/json

# Features
GET {{base_url}}/features.json
HTTP 200
Content-Type: application/json

# JOSM preset
GET {{base_url}}/preset.zip
HTTP 200
Content-Type: application/zip
