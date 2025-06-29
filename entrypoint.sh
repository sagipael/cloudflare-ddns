#!/bin/bash

set -e



function echoLog {
	local msg="$@"
	echo -e "$(date +%F" "%T)\t${msg[@]}"
}

function get_record_id {
	echo "Resolving record ID for $A_RECORD"
	A_RECORD_ID=$(curl -s "${API_BASE}/zones/${ZONE_ID}/dns_records?type=A&name=${A_RECORD}.${DOMAIN}" "${HEADERS[@]}" | jq -r '.result[0].id')

	if [[ -z "$A_RECORD_ID" || "$A_RECORD_ID" == "null" ]]; then
		echoLog	"[ERROR]	Unable to resolve A record ID for: ${A_RECORD}.${DOMAIN}"
		curl "${API_BASE}/zones/${ZONE_ID}/dns_records?type=A&name=${A_RECORD}.${DOMAIN}" "${HEADERS[@]}"
		exit 1
	fi

	export A_RECORD_ID
	# echo "$RECORD_ID" > "$RECORD_ID_FILE"
	# echo "Saved A_RECORD_ID: $A_RECORD_ID"
}

function get_zone_id {
	echo "Resolving zone ID for: $DOMAIN"
	RES="$(curl -s -X GET "${API_BASE}/zones?name=$DOMAIN" "${HEADERS[@]}")"
	ZONE_ID="$(echo "$RES" | jq -r '.result[0].id')"

	if [[ -z "$ZONE_ID" || "$ZONE_ID" == "null" ]]; then
		echoLog	"[ERROR]	Unable to resolve Zone ID for: ${DOMAIN}"
		curl  -X GET "${API_BASE}/zones?name=$DOMAIN" "${HEADERS[@]}"
		exit 1
	fi
	MAIL="$(echo "$RES" | jq -r '.result[0].account.name' | grep -i -o -E "[a-z0-9\.-]+@[a-z0-9\.-]+")"
	MAIL=${MAIL,,}

	export ZONE_ID
	export MAIL

	# echo "ZONE_ID: $ZONE_ID"
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


DATA=/data
TMP_IP_FILE="$DATA/current_ip"
RECORD_ID_FILE="$DATA/record_id"

API_BASE="https://api.cloudflare.com/client/v4"

mkdir -p $DATA


[[ ! "$TOKEN" ]] && { echoLog "[ERROR]	TOKEN cannot be empty" ; ERROR=1 ; }
[[ ! "$A_RECORD" ]] && { echoLog "[ERROR]	A_RECORD cannot be empty" ; ERROR=1 ; }
[[ ! "$DOMAIN" ]] && { echoLog "[ERROR]	DOMAIN cannot be empty" ; ERROR=1 ; }


[[ "$ERROR" ]] && exit 1
HEADERS=(
  -H "Authorization: Bearer $TOKEN"
  -H "Content-Type: application/json"
)



# Validate and parse schedule
[[ "$SCHEDULE" ]] && SLEEP_SECONDS=$(parse_schedule)

# First run: get Zone ID
get_zone_id

# First run: get record ID if not cached
get_record_id



if [ -z "$A_RECORD_ID" ] || [ "$A_RECORD_ID" = "null" ]; then
	echoLog "[ERROR]	Unable to resolve A record ID for $A_RECORD"
	exit 1
fi

echo -e "\n------------------------------------------------------------------"
echoLog "[DEBUG]	MAIL:		$MAIL"
echoLog "[DEBUG]	ZONE_ID:	$ZONE_ID"
echoLog "[DEBUG]	A_RECORD_ID:	$A_RECORD_ID"
echoLog "[DEBUG]	A Record:	${A_RECORD}.$DOMAIN"
echo -e "------------------------------------------------------------------\n"


if [[ "${SSL,,}" == "true" ]] ; then
	echo "#################################################################"
	echo "[INFO]	Create and auto-renew ssl certificate from LetsEncrypt"
	crond
	sleep 1
	CERTBOT_CONFIG=/etc/letsencrypt/cloudflare.ini
	mkdir -p $(dirname $CERTBOT_CONFIG)
	echo "dns_cloudflare_api_token = $TOKEN" > $CERTBOT_CONFIG
	chmod 600 $CERTBOT_CONFIG

	bash -x -c "certbot certonly --agree-tos -n -m $MAIL --dns-cloudflare --dns-cloudflare-credentials $CERTBOT_CONFIG -d \"*.$DOMAIN\" -d \"$DOMAIN\" || true"

	echo "[DEBUG]	Certificate Info:"
	certbot certificates
	CRON_JOB="0 3 * * * certbot renew > $DATA/cert.lastrun 2>&1"
	
	echo "[DEBUG]	CRON line: ${CRON_JOB}"
	
	# Check if the job already exists
	if [[ ! "$(crontab -l 2>/dev/null | grep -F "$CRON_JOB" )" ]] ; then
		# Add it to crontab
		(crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
		echo "[INFO]	Cron job added."
	else
		echo "[INFO]	Cron job already exists."
	fi
	echo "#################################################################"
fi
	


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
