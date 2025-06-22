#!/bin/bash

set -e

DATA=/data
TMP_IP_FILE="$DATA/current_ip"
RECORD_ID_FILE="$DATA/record_id"

API_BASE="https://api.cloudflare.com/client/v4"

mkdir -p $DATA

function echoLog {
	local msg="$@"
	echo -e "$(date +%F" "%T)\t${msg[@]}"
}

function get_record_id {
  echo "Resolving record ID for $A_RECORD"
  RECORD_ID=$(curl -s "${API_BASE}/zones/${ZONE_ID}/dns_records?type=A&name=${A_RECORD}.${DOMAIN}" "${HEADERS[@]}" | jq -r '.result[0].id')

  if [[ -z "$RECORD_ID" || "$RECORD_ID" == "null" ]]; then
    echoLog	"[ERROR]	Unable to resolve A record ID for: ${A_RECORD}.${DOMAIN}"
	curl "${API_BASE}/zones/${ZONE_ID}/dns_records?type=A&name=${A_RECORD}.${DOMAIN}" "${HEADERS[@]}"
    exit 1
  fi

  echo "$RECORD_ID" > "$RECORD_ID_FILE"
  echo "Saved A_RECORD_ID: $RECORD_ID"
}


function update_ip {
  CURRENT_IP=$(curl -s https://ipv4.icanhazip.com | tr -d '\n')
  OLD_IP=$(cat "$TMP_IP_FILE" 2>/dev/null || echo "")

  if [[ "$CURRENT_IP" != "$OLD_IP" ]] ; then
    echoLog "[INFO]	IP changed: $OLD_IP → $CURRENT_IP"
	RECORD=$(cat <<- EOF
	{ "type": "A",
	  "name": "$A_RECORD",
	  "comment": "updated by script at $(date +%F_%T)",
	  "content": "$CURRENT_IP",
	  "ttl": 180,
	  "proxied": false }
	EOF
	)
	
	RESPONSE=$(curl -s -X PUT "${API_BASE}/zones/$ZONE_ID/dns_records/$A_RECORD_ID" \
		"${HEADERS[@]}" \
		-d "${RECORD}" )
		
	SUCCESS=$(echo "$RESPONSE" | jq -r '.success')

    if [ "$SUCCESS" = "true" ]; then
      echo "$CURRENT_IP" > "$TMP_IP_FILE"
      echoLog "[INFO]	DNS record updated successfully."
	  echo "$RESPONSE" | jq
    else
      echoLog "[ERROR]	Failed to update DNS: $RESPONSE"
    fi
  else
    echoLog "[INFO]	IP unchanged ($CURRENT_IP). No update needed."
  fi
}

function parse_schedule {
  case "$SCHEDULE" in
    *m) MINUTES=${SCHEDULE%m}; echo $((MINUTES * 60));;
    *h) HOURS=${SCHEDULE%h}; echo $((HOURS * 3600));;
    *d) DAYS=${SCHEDULE%d}; echo $((DAYS * 86400));;
    *mo) MONTHS=${SCHEDULE%mo}; echo $((MONTHS * 2592000));;
    *)
      echoLog "Invalid SCHEDULE format: $SCHEDULE" >&2
      exit 1
      ;;
  esac
}

[[ ! "$TOKEN" ]] && { echoLog "[ERROR]	TOKEN cannot be empty" ; ERROR=1 ; }
[[ ! "$A_RECORD" ]] && { echoLog "[ERROR]	A_RECORD cannot be empty" ; ERROR=1 ; }
[[ ! "$DOMAIN" ]] && { echoLog "[ERROR]	DOMAIN cannot be empty" ; ERROR=1 ; }
[[ ! "$ZONE_ID" ]] && { echoLog "[ERROR]	ZONE_ID cannot be empty" ; ERROR=1 ; }

[[ "$ERROR" ]] && exit 1
HEADERS=(
  -H "Authorization: Bearer $TOKEN"
  -H "Content-Type: application/json"
)



# Validate and parse schedule
[[ "$SCHEDULE" ]] && SLEEP_SECONDS=$(parse_schedule)

# First run: get record ID if not cached
get_record_id


A_RECORD_ID=$(cat $RECORD_ID_FILE)
# Run immediately on start
#update_ip

if [ -z "$A_RECORD_ID" ] || [ "$A_RECORD_ID" = "null" ]; then
  echoLog "[ERROR]	Unable to resolve A record ID for $A_RECORD"
  exit 1
fi

echo -e "\n------------------------------------------------------------------"
echoLog "[DEBUG]	ZONE_ID:	$ZONE_ID"
echoLog "[DEBUG]	A_RECORD_ID:	$A_RECORD_ID"
echoLog "[DEBUG]	A Record:	${A_RECORD}.$DOMAIN"
echo -e "------------------------------------------------------------------\n"



# Run once at start
update_ip

if [[  "$SCHEDULE" && "$SLEEP_SECONDS" ]] ; then
	echoLog "[INFO]	Using schedule: $SCHEDULE → $SLEEP_SECONDS seconds"
	# Loop forever
	while true; do
		sleep "$SLEEP_SECONDS"
		update_ip
	done
fi
exit
