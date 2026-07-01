# Certificate Renewal Alert Setup for AWS EC2 + Nginx + Certbot

This setup provides automated SSL/TLS certificate expiry notifications to Microsoft Teams 7 days before renewal.

## Prerequisites

- AWS EC2 instance with Nginx and Certbot installed
- Sudo/root access
- MS Teams channel with webhook access

## Step 1: Get MS Teams Webhook URL

1. Open your MS Teams channel
2. Click the **...** (More options) next to the channel name
3. Select **Connectors**
4. Search for **Incoming Webhook** and click **Configure**
5. Name it: `Certificate Alerts` (or your preference)
6. Copy the webhook URL (looks like: `https://outlook.webhook.office.com/webhookb2/...`)

## Step 2: Deploy on EC2 Instance

### Copy Files

```bash
# Copy script to local bin
sudo cp check-cert-renewal.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/check-cert-renewal.sh

# Copy systemd files
sudo cp cert-renewal-check.service /etc/systemd/system/
sudo cp cert-renewal-check.timer /etc/systemd/system/

# Create config directory
sudo mkdir -p /etc/cert-renewal
sudo cp cert-renewal.env.template /etc/cert-renewal/cert-renewal.env
```

### Configure Environment

```bash
# Edit the webhook URL
sudo nano /etc/cert-renewal/cert-renewal.env
# OR
sudo vi /etc/cert-renewal/cert-renewal.env

# Set proper permissions
sudo chmod 600 /etc/cert-renewal/cert-renewal.env
```

### Enable and Start Timer

```bash
# Reload systemd daemon
sudo systemctl daemon-reload

# Enable timer (runs on boot)
sudo systemctl enable cert-renewal-check.timer

# Start timer immediately
sudo systemctl start cert-renewal-check.timer

# Verify status
sudo systemctl status cert-renewal-check.timer
sudo systemctl list-timers cert-renewal-check.timer
```

## Step 3: Test

### Manual Test

```bash
# Run the script manually to verify it works
sudo /usr/local/bin/check-cert-renewal.sh

# Check logs
sudo journalctl -u cert-renewal-check.service -n 50
sudo tail -f /var/log/cert-renewal-check.log
```

### Trigger Test Alert

To test Teams notification without waiting for a real certificate expiry:

```bash
# Temporarily set ALERT_DAYS to a large number to trigger test
export ALERT_DAYS=9999
export TEAMS_WEBHOOK_URL="YOUR_WEBHOOK_URL"
/usr/local/bin/check-cert-renewal.sh
```

## Step 4: Monitor

### View Timer Activity

```bash
# List all timers
sudo systemctl list-timers

# View next run
sudo systemctl list-timers --all

# Check service logs
sudo journalctl -u cert-renewal-check.service -n 100 -f
```

### View Certificate Status

```bash
# Check certificate expiry dates
sudo certbot certificates

# Manual renewal dry-run test
sudo certbot renew --dry-run --quiet
```

## Automation Options

### Option A: Systemd Timer (Recommended)
Already configured above - runs daily at 9 AM

### Option B: Cron Job (Alternative)

```bash
# Edit crontab
sudo crontab -e

# Add this line (9 AM daily)
0 9 * * * /usr/local/bin/check-cert-renewal.sh
```

## Customization

### Change Alert Timing

Edit `/etc/cert-renewal/cert-renewal.env`:
```
ALERT_DAYS=7  # Alert 7 days before expiry
```

### Change Check Frequency

Edit `/etc/systemd/system/cert-renewal-check.timer`:
```ini
OnCalendar=daily              # Change to: hourly, daily, weekly, etc.
OnCalendar=*-*-* 09:00:00     # Change the time (24-hour format)
```

Then reload: `sudo systemctl daemon-reload && sudo systemctl restart cert-renewal-check.timer`

### Multiple Domains

The script automatically checks all certificates in `/etc/letsencrypt/live/`. Each domain gets its own alert.

## Troubleshooting

### Script not executing
```bash
sudo chmod +x /usr/local/bin/check-cert-renewal.sh
sudo systemctl daemon-reload
```

### Teams webhook not receiving messages
```bash
# Test webhook manually
curl -X POST -H 'Content-Type: application/json' \
  --data '{"text":"Test message"}' \
  "YOUR_WEBHOOK_URL"
```

### Check environment variables
```bash
sudo systemctl show-environment cert-renewal-check.timer
```

### View full error logs
```bash
sudo journalctl -u cert-renewal-check.service -n 100 --no-pager
```

## Security Considerations

1. **Webhook URL Protection**
   - Store in `/etc/cert-renewal/cert-renewal.env` with `600` permissions
   - Use IAM role for secret management in production

2. **Rotation Secrets** (AWS Secrets Manager)
   ```bash
   # Fetch webhook from AWS Secrets Manager
   export TEAMS_WEBHOOK_URL=$(aws secretsmanager get-secret-value --secret-id cert-renewal-webhook --query SecretString --output text)
   ```

3. **EC2 IAM Role Setup**
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": "secretsmanager:GetSecretValue",
         "Resource": "arn:aws:secretsmanager:*:*:secret:cert-renewal-webhook-*"
       }
     ]
   }
   ```

## AWS CloudWatch Integration (Optional)

Monitor alerts via CloudWatch:

```bash
# Forward logs to CloudWatch
sudo yum install awslogs  # or apt-get on Ubuntu

# Configure in /etc/awslogs/config/awslogs.conf
[/var/log/cert-renewal-check.log]
log_group_name = /aws/ec2/certificate-renewal
log_stream_name = {instance_id}
```

## Certbot Auto-Renewal

Certbot already has built-in auto-renewal. This script enhances visibility:

```bash
# Verify certbot is set up for auto-renewal
sudo certbot renew --dry-run --quiet

# View certbot renewal logs
sudo tail -f /var/log/letsencrypt/letsencrypt.log
```

## Support & Logs

- Service logs: `sudo journalctl -u cert-renewal-check.service`
- Local logs: `/var/log/cert-renewal-check.log`
- Systemd timer logs: `sudo systemctl status cert-renewal-check.timer`
