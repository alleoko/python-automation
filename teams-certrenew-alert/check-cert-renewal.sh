#!/bin/bash
# Check certificate expiry and alert via MS Teams webhook
# Installation: sudo cp check-cert-renewal.sh /usr/local/bin/
# Cron setup: 0 9 * * * /usr/local/bin/check-cert-renewal.sh

set -e

# Load configuration from file (parsed line-by-line to safely handle the &
# characters in the webhook URL, with or without surrounding quotes).
CONFIG_FILE="/etc/cert-renewal/cert-renewal.env"
if [ -f "$CONFIG_FILE" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line#"${line%%[![:space:]]*}"}"
        [ -z "$line" ] && continue
        [ "${line#\#}" != "$line" ] && continue
        key="${line%%=*}"
        value="${line#*=}"
        key="$(printf '%s' "$key" | tr -d '[:space:]')"
        case "$value" in
            \"*\") value="${value#\"}"; value="${value%\"}" ;;
            \'*\') value="${value#\'}"; value="${value%\'}" ;;
        esac
        case "$key" in
            TEAMS_WEBHOOK_URL) TEAMS_WEBHOOK_URL="$value" ;;
            CERT_PATH)         CERT_PATH="$value" ;;
            ALERT_DAYS)        ALERT_DAYS="$value" ;;
        esac
    done < "$CONFIG_FILE"
fi

TEAMS_WEBHOOK_URL="${TEAMS_WEBHOOK_URL:-}"
CERT_PATH="${CERT_PATH:-/etc/letsencrypt/live}"
ALERT_DAYS="${ALERT_DAYS:-7}"
HOSTNAME=$(hostname)

if [ -z "$TEAMS_WEBHOOK_URL" ]; then
    echo "Error: TEAMS_WEBHOOK_URL environment variable not set"
    exit 1
fi

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

log() {
    echo -e "${1}" | tee -a /var/log/cert-renewal-check.log
}

send_teams_alert() {
    local domain=$1
    local days_left=$2
    local expiry_date=$3
    local severity=$4

    local payload=$(cat <<EOF
{
    "domain": "$domain",
    "days_left": "$days_left",
    "daysLeft": "$days_left",
    "expires": "$expiry_date",
    "expiryDate": "$expiry_date",
    "severity": "$severity",
    "hostname": "$HOSTNAME"
}
EOF
)

    curl -X POST -H 'Content-Type: application/json' \
        --data-binary "$payload" \
        "$TEAMS_WEBHOOK_URL" 2>/dev/null || log "${RED}Failed to send Teams notification${NC}"
}

check_certificates() {
    local alert_sent=0

    if [ ! -d "$CERT_PATH" ]; then
        log "${YELLOW}Certificate path not found: $CERT_PATH${NC}"
        return
    fi

    for cert_dir in "$CERT_PATH"/*; do
        if [ -d "$cert_dir" ]; then
            local domain=$(basename "$cert_dir")
            local cert_file="$cert_dir/cert.pem"

            if [ ! -f "$cert_file" ]; then
                continue
            fi

            local expiry_epoch=$(openssl x509 -noout -dates -in "$cert_file" | grep notAfter | cut -d= -f2)
            local expiry_date=$(date -d "$expiry_epoch" '+%Y-%m-%d')
            local expiry_timestamp=$(date -d "$expiry_date" +%s)
            local now_timestamp=$(date +%s)
            local seconds_left=$((expiry_timestamp - now_timestamp))
            local days_left=$((seconds_left / 86400))

            log "Checking $domain: expires in $days_left days ($expiry_date)"

            if [ "$days_left" -le "$ALERT_DAYS" ]; then
                if [ "$days_left" -le 0 ]; then
                    log "${RED}CRITICAL: Certificate expired for $domain!${NC}"
                    send_teams_alert "$domain" "$days_left" "$expiry_date" "critical"
                else
                    log "${YELLOW}WARNING: Certificate expiring soon for $domain${NC}"
                    send_teams_alert "$domain" "$days_left" "$expiry_date" "warning"
                fi
                alert_sent=1
            elif [ "$days_left" -le 30 ]; then
                log "${GREEN}INFO: Certificate will expire in $days_left days for $domain${NC}"
            fi
        fi
    done

    return $alert_sent
}

check_certificates
