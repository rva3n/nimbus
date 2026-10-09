#!/bin/sh
# IP-геолокация для Nimbus: сначала ipwho.is, при неудаче — ipinfo.io.
# Вывод — одна строка компактного JSON: {"city":"…","lat":…,"lon":…}
j=$(curl -s --max-time 12 https://ipwho.is/)
lat=$(printf %s "$j" | jq -r '.latitude // empty' 2>/dev/null)
if [ -n "$lat" ]; then
    printf %s "$j" | jq -c '{city: (.city // ""), lat: .latitude, lon: .longitude}'
    exit 0
fi
curl -s --max-time 12 https://ipinfo.io/json | jq -c '{city: (.city // ""), lat: (.loc | split(",")[0] | tonumber), lon: (.loc | split(",")[1] | tonumber)}'
