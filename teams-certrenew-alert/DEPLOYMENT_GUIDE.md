# Certificate Renewal Alert System - Deployment Guide

**Version:** 1.0  
**Date:** 2026-06-18  
**Author:** DevOps Team  
**Purpose:** Automated SSL/TLS certificate expiry notifications to Microsoft Teams

---

## Table of Contents
1. [System Overview](#system-overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Component Setup](#component-setup)
5. [Deployment Steps](#deployment-steps)
6. [Configuration](#configuration)
7. [Testing](#testing)
8. [Troubleshooting](#troubleshooting)
9. [Maintenance](#maintenance)

---

## System Overview

**What it does:**
- Monitors SSL/TLS certificates on AWS EC2 instances
- Automatically checks daily at 9 AM
- Sends alerts to Microsoft Teams 7 days before certificate expiry
- Alerts include: domain name, days remaining, expiry date, severity level

**Key Benefits:**
- ✅ Prevents unexpected certificate expirations
- ✅ Real-time team notifications via Teams
- ✅ Automatic daily checks (no manual intervention)
- ✅ Detailed alert messages with severity levels
- ✅ Easy to configure and deploy

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    AWS EC2 Instance                         │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  check-cert-renewal.sh (runs daily at 9 AM)           │ │
│  │  - Checks /etc/letsencrypt/live/ for certs            │ │
│  │  - Calculates days until expiry                        │ │
│  │  - Sends alerts if < 7 days remaining                 │ │
│  └────────────────────┬─────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                         │
                         │ (HTTPS POST)
                         │ MessageCard format
                         ▼
┌─────────────────────────────────────────────────────────────┐
│             Microsoft Power Automate Webhook                 │
│  - Receives certificate data                                │
│  - Parses MessageCard format                                │
│  - Routes to Teams channel                                  │
└────────────────────┬────────────────────────────────────────┘
                     │
                     │ (Teams API)
                     ▼
┌─────────────────────────────────────────────────────────────┐
│          Microsoft Teams - Certificate Alerts Channel       │
│  - Displays formatted alert messages                        │
│  - Shows domain, days left, expiry date, severity           │
│  - Available for team review and action                     │
└─────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

**On EC2 Instance:**
- Ubuntu 18.04+ or similar Linux distro
- Nginx or Apache with Certbot/Let's Encrypt
- Sudo/root access
- curl installed
- openssl installed

**External Services:**
- Microsoft Teams account with channel access
- AWS account with EC2 instance
- Microsoft Power Automate account (free tier OK)

**Required Permissions:**
- Channel owner access for Teams channel setup
- EC2 root/sudo access for service installation

---

## Component Setup

### 1. Power Automate Webhook Setup

**Purpose:** Acts as a bridge between EC2 and Teams

**Steps:**
1. Go to `https://make.powerautomate.com`
2. Click **+ Create** → **Cloud flow** → **Instant cloud flow**
3. Name: `Certificate Renewal Alert`
4. Search for trigger: `When a Teams webhook request is received`
5. Click **Create**
6. Copy the webhook URL generated
7. Add action: **Post message in a chat or channel**
   - Team: Select your team
   - Channel: Your certificate alerts channel
   - Message: Use MessageCard format
8. Click **Save**

**Webhook URL Format:**
```
https://default[ID].1c.environment.api.powerplatform.com:443/powerautomate/automations/direct/workflows/[WORKFLOW_ID]/triggers/manual/paths/invoke?api-version=1&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=[SIGNATURE]
```

---

## Deployment Steps

### Step 1: Prepare Files on Local Machine

Ensure you have these files in your CertNotif directory:
- `check-cert-renewal.sh` - Main monitoring script
- `cert-renewal.env` - Configuration file
- `cert-renewal-check.service` - Systemd service
- `cert-renewal-check.timer` - Systemd timer

### Step 2: Copy Files to EC2

```bash
# Replace YOUR_EC2_IP with actual IP
EC2_IP="your-ec2-ip-here"
EC2_USER="ec2-user"

# Copy files to EC2 temp folder
scp check-cert-renewal.sh ${EC2_USER}@${EC2_IP}:/tmp/
scp cert-renewal.env ${EC2_USER}@${EC2_IP}:/tmp/
scp cert-renewal-check.service ${EC2_USER}@${EC2_IP}:/tmp/
scp cert-renewal-check.timer ${EC2_USER}@${EC2_IP}:/tmp/
```

### Step 3: SSH into EC2 and Install

```bash
ssh ${EC2_USER}@${EC2_IP}

# Create configuration directory
sudo mkdir -p /etc/cert-renewal

# Copy script to binary location
sudo cp /tmp/check-cert-renewal.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/check-cert-renewal.sh

# Copy configuration
sudo cp /tmp/cert-renewal.env /etc/cert-renewal/
sudo chmod 600 /etc/cert-renewal/cert-renewal.env

# Copy systemd files
sudo cp /tmp/cert-renewal-check.service /etc/systemd/system/
sudo cp /tmp/cert-renewal-check.timer /etc/systemd/system/

# Reload systemd daemon
sudo systemctl daemon-reload

# Enable timer (starts on boot)
sudo systemctl enable cert-renewal-check.timer

# Start timer immediately
sudo systemctl start cert-renewal-check.timer

# Verify status
sudo systemctl status cert-renewal-check.timer
```

### Step 4: Verify Deployment

```bash
# Check timer is active
sudo systemctl list-timers cert-renewal-check.timer

# View next scheduled run
sudo systemctl list-timers --all

# Check recent logs
sudo journalctl -u cert-renewal-check.service -n 20
```

---

## Configuration

### Environment Variables (cert-renewal.env)

| Variable | Value | Description |
|----------|-------|-------------|
| `TEAMS_WEBHOOK_URL` | Power Automate webhook URL | Where alerts are sent |
| `CERT_PATH` | `/etc/letsencrypt/live` | Location of certificates |
| `ALERT_DAYS` | `7` | Days before expiry to alert |

**Example cert-renewal.env:**
```
TEAMS_WEBHOOK_URL=https://default60210d45ac5844a8a263c4fe378e37.1c.environment.api.powerplatform.com:443/powerautomate/automations/direct/workflows/526e759aada14664a3e3fbdde8837114/triggers/manual/paths/invoke?api-version=1&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=iLB5Yg2SDwcUdtpFPHfJdFLu9PXK-1DYEbuw-mjSZdQ

CERT_PATH=/etc/letsencrypt/live

ALERT_DAYS=7
```

### Systemd Timer Schedule

**File:** `/etc/systemd/system/cert-renewal-check.timer`

```ini
[Unit]
Description=Certificate Renewal Check Timer
Requires=cert-renewal-check.service

[Timer]
OnCalendar=daily              # Daily checks
OnCalendar=*-*-* 09:00:00     # At 9 AM (24-hour format)
AccuracySec=1min
Persistent=true

[Install]
WantedBy=timers.target
```

**To Change Schedule:**
```bash
# Edit timer
sudo nano /etc/systemd/system/cert-renewal-check.timer

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart cert-renewal-check.timer
```

---

## Testing

### Test 1: Manual Script Execution

```bash
# Run script manually
sudo /usr/local/bin/check-cert-renewal.sh

# Check output
sudo journalctl -u cert-renewal-check.service -n 50

# Check Teams channel for test message
```

### Test 2: Force Alert (Temporary Config)

```bash
# Temporarily set large alert threshold to trigger test
export ALERT_DAYS=9999
export TEAMS_WEBHOOK_URL="<your-webhook-url>"
/usr/local/bin/check-cert-renewal.sh

# Restore original config after test
sudo nano /etc/cert-renewal/cert-renewal.env
```

### Test 3: Webhook Connectivity

```bash
# Test webhook directly
curl -X POST \
  -H 'Content-Type: application/json' \
  --data '{
    "@type": "MessageCard",
    "@context": "https://schema.org/extensions",
    "summary": "Test Alert",
    "themeColor": "0078D4",
    "sections": [{
      "activityTitle": "🔒 Test Certificate Alert",
      "facts": [
        {"name": "Domain", "value": "test.example.com"},
        {"name": "Days Until Expiry", "value": "7 days"},
        {"name": "Expiry Date", "value": "2026-06-25"}
      ]
    }]
  }' \
  'YOUR_WEBHOOK_URL'
```

### Test 4: View Certificate Status

```bash
# List all certificates
sudo certbot certificates

# View specific certificate details
sudo openssl x509 -noout -dates -in /etc/letsencrypt/live/example.com/cert.pem

# Test renewal (dry run)
sudo certbot renew --dry-run --quiet
```

---

## Troubleshooting

### Issue 1: Script Not Executing

**Symptoms:** Timer shows scheduled but script never runs

**Solution:**
```bash
# Check script permissions
sudo chmod +x /usr/local/bin/check-cert-renewal.sh

# Check service file
sudo cat /etc/systemd/system/cert-renewal-check.service

# Reload systemd
sudo systemctl daemon-reload
sudo systemctl restart cert-renewal-check.timer

# Check logs
sudo journalctl -u cert-renewal-check.service
```

### Issue 2: Teams Not Receiving Messages

**Symptoms:** Script runs but no Teams alert appears

**Solution:**
```bash
# 1. Verify webhook URL is set
sudo cat /etc/cert-renewal/cert-renewal.env

# 2. Test webhook connectivity
curl -X POST -H 'Content-Type: application/json' \
  --data '{"test":"message"}' \
  "YOUR_WEBHOOK_URL"

# 3. Check Teams channel name and permissions
# 4. Verify Power Automate flow is active
```

### Issue 3: High Memory/CPU Usage

**Symptoms:** Script consumes excessive resources

**Solution:**
```bash
# Reduce check frequency
sudo nano /etc/systemd/system/cert-renewal-check.timer
# Change OnCalendar to: weekly or OnCalendar=*-*-* 02:00:00

# Reload
sudo systemctl daemon-reload
sudo systemctl restart cert-renewal-check.timer
```

### Issue 4: Certificate Path Not Found

**Symptoms:** "Certificate path not found" error

**Solution:**
```bash
# Verify correct path
ls -la /etc/letsencrypt/live/

# Check if Certbot is installed
sudo certbot --version

# Update cert-renewal.env with correct path
sudo nano /etc/cert-renewal/cert-renewal.env
```

---

## Maintenance

### Daily Checks

**Verify timer is running:**
```bash
sudo systemctl status cert-renewal-check.timer
```

### Weekly Review

**Check recent logs:**
```bash
sudo journalctl -u cert-renewal-check.service --since "1 week ago"
```

**Verify certificate status:**
```bash
sudo certbot certificates
```

### Monthly Maintenance

**1. Review Power Automate flow**
- Go to `https://make.powerautomate.com`
- Check "Certificate Renewal Alert" flow status
- Verify webhook is still active

**2. Update webhook URL (if needed)**
```bash
# Get new webhook from Power Automate
# Update configuration
sudo nano /etc/cert-renewal/cert-renewal.env

# Reload
sudo systemctl restart cert-renewal-check.timer
```

**3. Check certificate renewal logs**
```bash
sudo tail -f /var/log/letsencrypt/letsencrypt.log
```

### Quarterly Updates

**1. Review and update documentation**
**2. Test disaster recovery**
**3. Validate all certificates are renewing properly**
**4. Check for Certbot updates**

---

## Alert Message Format

**Example Teams Alert:**

```
🔒 SSL/TLS Certificate Renewal Alert
Hostname: your-server

Domain: example.com
Days Until Expiry: 7 days
Expiry Date: 2026-06-25
Severity: warning

Recommended Action:
Certbot should auto-renew, but verify with: sudo certbot renew --dry-run
```

**Severity Levels:**
- 🔴 **Critical:** 0 or fewer days (already expired)
- 🟠 **Warning:** 1-7 days
- 🟡 **Info:** 8-30 days

---

## Support & Documentation

**Quick Commands:**
```bash
# View timer schedule
sudo systemctl list-timers cert-renewal-check.timer

# View full logs
sudo journalctl -u cert-renewal-check.service -n 100 --no-pager

# Manual run
sudo /usr/local/bin/check-cert-renewal.sh

# Stop/restart timer
sudo systemctl stop cert-renewal-check.timer
sudo systemctl start cert-renewal-check.timer
```

**Log Locations:**
- Systemd logs: `journalctl -u cert-renewal-check.service`
- Certificate logs: `/var/log/letsencrypt/letsencrypt.log`
- Custom logs: `/var/log/cert-renewal-check.log`

**Contact:** DevOps Team

---

**Document Version:** 1.0  
**Last Updated:** 2026-06-18  
**Next Review:** 2026-09-18
