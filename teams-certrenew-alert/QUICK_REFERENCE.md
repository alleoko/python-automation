# Certificate Renewal Alert System - Quick Reference Guide

## System at a Glance

| Aspect | Details |
|--------|---------|
| **Purpose** | Automated SSL certificate expiry alerts to Teams |
| **Frequency** | Daily at 9 AM (configurable) |
| **Alert Trigger** | 7 days before certificate expiry |
| **Deployment** | AWS EC2 + Microsoft Power Automate + Teams |
| **Status** | Active & Monitoring |

---

## File Locations on EC2

| File | Location | Purpose |
|------|----------|---------|
| Script | `/usr/local/bin/check-cert-renewal.sh` | Main monitoring script |
| Config | `/etc/cert-renewal/cert-renewal.env` | Environment variables |
| Service | `/etc/systemd/system/cert-renewal-check.service` | Systemd service definition |
| Timer | `/etc/systemd/system/cert-renewal-check.timer` | Systemd schedule |
| Logs | `/var/log/cert-renewal-check.log` | Application logs |
| Cert Logs | `/var/log/letsencrypt/letsencrypt.log` | Certbot logs |

---

## Quick Commands

| Task | Command |
|------|---------|
| **Check Status** | `sudo systemctl status cert-renewal-check.timer` |
| **View Schedule** | `sudo systemctl list-timers cert-renewal-check.timer` |
| **Run Manually** | `sudo /usr/local/bin/check-cert-renewal.sh` |
| **View Logs** | `sudo journalctl -u cert-renewal-check.service -n 50` |
| **List Certificates** | `sudo certbot certificates` |
| **Test Renewal** | `sudo certbot renew --dry-run --quiet` |
| **Restart Timer** | `sudo systemctl restart cert-renewal-check.timer` |
| **Stop Timer** | `sudo systemctl stop cert-renewal-check.timer` |
| **Enable on Boot** | `sudo systemctl enable cert-renewal-check.timer` |
| **Edit Config** | `sudo nano /etc/cert-renewal/cert-renewal.env` |

---

## Configuration Values

| Variable | Current Value | Description | Edit? |
|----------|--------------|-------------|-------|
| `TEAMS_WEBHOOK_URL` | `https://default60210d45ac5844a8a263c4fe378e37.1c...` | Power Automate webhook | Only if webhook changes |
| `CERT_PATH` | `/etc/letsencrypt/live` | Certificate directory | Only if path changes |
| `ALERT_DAYS` | `7` | Days before expiry to alert | Modify per team needs |

---

## Power Automate Webhook Setup

**Purpose:** Acts as a bridge between EC2 and Teams for certificate alerts

**Quick Setup Steps:**

1. Go to `https://make.powerautomate.com`
2. Click **+ Create** → **Cloud flow** → **Instant cloud flow**
3. Name: `Certificate Renewal Alert`
4. Search for trigger: `When a Teams webhook request is received`
5. Click **Create**
6. **Copy the webhook URL generated** (save this!)
7. Add action: **Post message in a chat or channel**
   - Team: Select your team
   - Channel: Your certificate alerts channel
   - Message: Use MessageCard format
8. Click **Save**
9. Update `/etc/cert-renewal/cert-renewal.env` with the webhook URL:
   ```bash
   sudo nano /etc/cert-renewal/cert-renewal.env
   # Update TEAMS_WEBHOOK_URL=<paste-your-webhook-url>
   ```
10. Restart timer:
    ```bash
    sudo systemctl restart cert-renewal-check.timer
    ```

**Webhook URL Format Example:**
```
https://default[ID].1c.environment.api.powerplatform.com:443/powerautomate/automations/direct/workflows/[WORKFLOW_ID]/triggers/manual/paths/invoke?api-version=1&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=[SIGNATURE]
```

**Test Webhook Connectivity:**
```bash
curl -X POST \
  -H 'Content-Type: application/json' \
  --data '{"test":"message"}' \
  "YOUR_WEBHOOK_URL"
```
**Expected:** HTTP 200 response

---

## Deployment Checklist

- [ ] EC2 instance has Certbot/Let's Encrypt installed
- [ ] Power Automate webhook created and tested
- [ ] Teams channel created for alerts
- [ ] Files copied to EC2 `/tmp` directory
- [ ] Files moved to proper locations (see File Locations)
- [ ] Permissions set correctly (script +x, config 600)
- [ ] Systemd daemon reloaded
- [ ] Timer enabled and started
- [ ] Manual test executed successfully
- [ ] Message received in Teams channel
- [ ] Logs verified in journalctl
- [ ] Documentation shared with team

---

## Troubleshooting Decision Tree

```
Timer not running?
├─ YES → Check: sudo systemctl status cert-renewal-check.timer
└─ NO → Go to: Script not executing

Script not executing?
├─ Check permissions: sudo chmod +x /usr/local/bin/check-cert-renewal.sh
├─ Check logs: sudo journalctl -u cert-renewal-check.service
└─ Reload: sudo systemctl daemon-reload && restart timer

Teams not receiving alerts?
├─ Verify webhook URL: sudo cat /etc/cert-renewal/cert-renewal.env
├─ Test webhook: curl -X POST ... (see Testing section)
├─ Check Power Automate: https://make.powerautomate.com
└─ Verify Teams channel permissions

Certificate path not found?
├─ Check path exists: ls -la /etc/letsencrypt/live/
├─ Verify Certbot: sudo certbot --version
└─ Update config: sudo nano /etc/cert-renewal/cert-renewal.env

No certificates found?
├─ Check Certbot: sudo certbot certificates
└─ Install Certbot if needed
```

---

## Webhook Testing

**Test webhook connectivity:**
```bash
curl -X POST \
  -H 'Content-Type: application/json' \
  --data '{"test":"message"}' \
  "PASTE_YOUR_WEBHOOK_URL_HERE"
```

**Expected Response:** Empty response with HTTP 200 status  
**Failed Response:** HTTP 400 or 403 error

---

## Performance Metrics

| Metric | Expected Value |
|--------|-----------------|
| Script execution time | < 2 seconds |
| Memory usage | < 10 MB |
| CPU usage | < 1% |
| Alert delivery time | < 5 seconds |
| Daily log size | < 1 KB |

---

## Monitoring Schedule

| Frequency | Task |
|-----------|------|
| Daily | Check Teams for alerts |
| Weekly | Review journalctl logs |
| Monthly | Verify certificate renewal progress |
| Quarterly | Test disaster recovery |

---

## Contact & Escalation

| Level | Contact | Action |
|-------|---------|--------|
| Tier 1 | DevOps Team | Check logs and basic troubleshooting |
| Tier 2 | Cloud Admin | Power Automate/Teams configuration |
| Tier 3 | AWS Support | EC2/Certbot issues |

---

## Additional Resources

- **Full Guide:** See DEPLOYMENT_GUIDE.md
- **Setup Instructions:** See SETUP.md
- **Quick Start:** See QUICK_START.md
- **Certbot Docs:** https://certbot.eff.org/docs/
- **Power Automate:** https://make.powerautomate.com/
- **Microsoft Teams:** https://teams.microsoft.com/

---

**Last Updated:** 2026-06-18  
**Version:** 1.0  
**Status:** Production Ready
