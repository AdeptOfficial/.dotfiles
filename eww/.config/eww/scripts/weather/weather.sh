#!/bin/bash
# Fetch weather from Open-Meteo API (free, no API key required)

# Get location from IP
LOCATION=$(curl -s "http://ip-api.com/json" 2>/dev/null)
if [[ -z "$LOCATION" ]]; then
    echo '{"temp": "--", "condition": "Offline", "icon": "☁️", "city": ""}'
    exit 0
fi

LAT=$(echo "$LOCATION" | jq -r '.lat')
LON=$(echo "$LOCATION" | jq -r '.lon')
CITY=$(echo "$LOCATION" | jq -r '.city')

# Fetch weather data from Open-Meteo
DATA=$(curl -s "https://api.open-meteo.com/v1/forecast?latitude=$LAT&longitude=$LON&current=temperature_2m,weather_code&timezone=auto" 2>/dev/null)

if [[ -z "$DATA" ]] || [[ "$(echo "$DATA" | jq -r '.current')" == "null" ]]; then
    echo '{"temp": "--", "condition": "Error", "icon": "☁️", "city": ""}'
    exit 0
fi

TEMP=$(echo "$DATA" | jq -r '.current.temperature_2m | round')
WEATHER_CODE=$(echo "$DATA" | jq -r '.current.weather_code')

# Map weather codes to conditions and icons
case "$WEATHER_CODE" in
    0)
        CONDITION="Clear"
        ICON_CHAR="☀️"
        ;;
    1)
        CONDITION="Mostly Clear"
        ICON_CHAR="🌤️"
        ;;
    2)
        CONDITION="Partly Cloudy"
        ICON_CHAR="⛅"
        ;;
    3)
        CONDITION="Cloudy"
        ICON_CHAR="☁️"
        ;;
    45|48)
        CONDITION="Foggy"
        ICON_CHAR="🌫️"
        ;;
    51|53|55)
        CONDITION="Drizzle"
        ICON_CHAR="🌧️"
        ;;
    56|57)
        CONDITION="Freezing Drizzle"
        ICON_CHAR="🌧️"
        ;;
    61|63|65)
        CONDITION="Rain"
        ICON_CHAR="🌧️"
        ;;
    66|67)
        CONDITION="Freezing Rain"
        ICON_CHAR="🌧️"
        ;;
    71|73|75)
        CONDITION="Snow"
        ICON_CHAR="❄️"
        ;;
    77)
        CONDITION="Snow Grains"
        ICON_CHAR="❄️"
        ;;
    80|81|82)
        CONDITION="Rain Showers"
        ICON_CHAR="🌧️"
        ;;
    85|86)
        CONDITION="Snow Showers"
        ICON_CHAR="🌨️"
        ;;
    95)
        CONDITION="Thunderstorm"
        ICON_CHAR="⛈️"
        ;;
    96|99)
        CONDITION="Thunderstorm"
        ICON_CHAR="⛈️"
        ;;
    *)
        CONDITION="Unknown"
        ICON_CHAR="🌡️"
        ;;
esac

# Output JSON for eww
echo "{\"temp\": \"$TEMP\", \"condition\": \"$CONDITION\", \"icon\": \"$ICON_CHAR\", \"city\": \"$CITY\"}"
