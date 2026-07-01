# Quick Start: 5-Minute Setup

## On Your Machine

1. **Get Teams Webhook URL**
   - Teams > ... (channel options) > Connectors > Incoming Webhook > Configure
   - Copy the URL

## On AWS EC2 Instance

```bash
# Clone/download the files
cd /tmp
wget https://your-repo/CertNotif.zip && unzip CertNotif.zip
cd CertNotif

# Run setup script
sudo bash -c '
  cp check-cert-renewal.sh /usr/local/bin/
  chmod +x /usr/local/bin/check-cert-renewal.sh
  
  mkdir -p /etc/cert-renewal
  cp cert-renewal.env.template /etc/cert-renewal/cert-renewal.env
  chmod 600 /etc/cert-renewal/cert-renewal.env
  
  cp cert-renewal-check.service /etc/systemd/system/
  cp cert-renewal-check.timer /etc/systemd/system/
  
  systemctl daemon-reload
  systemctl enable cert-renewal-check.timer
  systemctl start cert-renewal-check.timer
'

# Configure webhook URL
sudo nano /etc/cert-renewal/cert-renewal.env
# Add your Teams webhook URL: TEAMS_WEBHOOK_URL=https://outlook.webhook.office.com/...

# Test
sudo /usr/local/bin/check-cert-renewal.sh
```

## Verify It's Working

```bash
# Check timer is scheduled
sudo systemctl list-timers cert-renewal-check.timer

# View logs
sudo journalctl -u cert-renewal-check.service -n 20

# Check certificate status
sudo certbot certificates
```

## Done!

Your EC2 instance will now send MS Teams alerts 7 days before any SSL certificate expires. Alerts run automatically daily at 9 AM.
