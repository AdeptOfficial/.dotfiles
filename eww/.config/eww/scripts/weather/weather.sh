#!/bin/bash
# Fetch weather from OpenWeather API

source ~/.config/eww/secrets

# Set your city (can be city name or "lat,lon")
CITY="Chicago"
UNITS="metric"  # metric = Celsius, imperial = Fahrenheit

# Get location from IP if auto
if [[ "$CITY" == "auto" ]]; then
    LOCATION=$(curl -s "http://ip-api.com/json" | jq -r '"\(.lat),\(.lon)"')
    LAT=$(echo "$LOCATION" | cut -d',' -f1)
    LON=$(echo "$LOCATION" | cut -d',' -f2)
    URL="https://api.openweathermap.org/data/2.5/weather?lat=$LAT&lon=$LON&units=$UNITS&appid=$OPENWEATHER_API_KEY"
else
    URL="https://api.openweathermap.org/data/2.5/weather?q=$CITY&units=$UNITS&appid=$OPENWEATHER_API_KEY"
fi

# Fetch weather data
DATA=$(curl -s "$URL")

# Parse response
TEMP=$(echo "$DATA" | jq -r '.main.temp | round')
CONDITION=$(echo "$DATA" | jq -r '.weather[0].main')
ICON=$(echo "$DATA" | jq -r '.weather[0].icon')
CITY_NAME=$(echo "$DATA" | jq -r '.name')

# Map OpenWeather icons to emoji/nerd font
case "$ICON" in
    01d) ICON_CHAR="☀️" ;;   # clear sky day
    01n) ICON_CHAR="🌙" ;;   # clear sky night
    02d|02n) ICON_CHAR="⛅" ;;  # few clouds
    03d|03n) ICON_CHAR="☁️" ;;  # scattered clouds
    04d|04n) ICON_CHAR="☁️" ;;  # broken clouds
    09d|09n) ICON_CHAR="🌧️" ;; # shower rain
    10d|10n) ICON_CHAR="🌧️" ;; # rain
    11d|11n) ICON_CHAR="⛈️" ;; # thunderstorm
    13d|13n) ICON_CHAR="❄️" ;; # snow
    50d|50n) ICON_CHAR="🌫️" ;; # mist
    *) ICON_CHAR="🌡️" ;;
esac

# Output JSON for eww
echo "{\"temp\": \"$TEMP\", \"condition\": \"$CONDITION\", \"icon\": \"$ICON_CHAR\", \"city\": \"$CITY_NAME\"}"
