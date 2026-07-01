#!/bin/bash
# Alternative setup using cron instead of systemd

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing certificate renewal alert (cron version)..."

# Copy script
sudo cp "$SCRIPT_DIR/check-cert-renewal.sh" /usr/local/bin/
sudo chmod +x /usr/local/bin/check-cert-renewal.sh

# Create config directory
sudo mkdir -p /etc/cert-renewal
sudo cp "$SCRIPT_DIR/cert-renewal.env.template" /etc/cert-renewal/cert-renewal.env
sudo chmod 600 /etc/cert-renewal/cert-renewal.env

echo ""
echo "✓ Script installed to /usr/local/bin/check-cert-renewal.sh"
echo "✓ Config template created at /etc/cert-renewal/cert-renewal.env"
echo ""
echo "Next steps:"
echo "1. Edit /etc/cert-renewal/cert-renewal.env and add your Teams webhook URL"
echo "2. Run: sudo crontab -e"
echo "3. Add this line:"
echo "   0 9 * * * source /etc/cert-renewal/cert-renewal.env && /usr/local/bin/check-cert-renewal.sh"
echo "4. Test with: sudo /usr/local/bin/check-cert-renewal.sh"
echo ""
echo "View logs with: sudo tail -f /var/log/cert-renewal-check.log"
