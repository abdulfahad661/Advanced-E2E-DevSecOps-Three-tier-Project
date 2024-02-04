#!/bin/bash

# Replace with your desired domain and file path
DOMAIN="app-sonarqube.duckdns.org"
CONFIG_FILE="/etc/nginx/sites-available/$DOMAIN"

# Create Nginx configuration file
sudo tee "$CONFIG_FILE" > /dev/null <<'EOL'
mmap $host $backend_ip_sonar {
    default "";
    app-sonarqube.duckdns.org $(dig +short myip.opendns.com @resolver1.opendns.com):9000;
}

upstream sonarqube {
    server $backend_ip_sonar;
}

server {
    listen 80;
    server_name  app-sonarqube.duckdns.org;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name app-sonarqube.duckdns.org;

    ssl_certificate           /etc/letsencrypt/live/app-sonarqube.duckdns.org/fullchain.pem;
    ssl_certificate_key       /etc/letsencrypt/live/app-sonarqube.duckdns.org/privkey.pem;

    access_log  /var/log/nginx/sonarqube.access.log;
    error_log   /var/log/nginx/sonarqube.error.log;

    proxy_buffers 16 64k;
    proxy_buffer_size 128k;

    location / {
        proxy_pass http://sonarqube;
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
        proxy_redirect off;

        proxy_set_header Host            $host;
        proxy_set_header X-Real-IP       $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}

EOL

# Enable the configuration file
sudo ln -s "$CONFIG_FILE" "/etc/nginx/sites-enabled/"

# Test for syntax errors
sudo nginx -t

# If syntax is OK, reload Nginx
if [ $? -eq 0 ]; then
    sudo systemctl reload nginx
    sudo certbot --nginx -d $DOMAIN
    sudo systemctl status certbot.timer
    sudo certbot renew --dry-run

    echo "Nginx configuration and Encryption reloaded successfully."
else
    echo "Error: Nginx configuration has syntax errors. Please check and fix."
fi