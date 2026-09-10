#cloud-config

# Update system and install dependencies
package_update: true
package_upgrade: true

packages:
  - nginx
  - wget
  - tar
  - certbot
  - python3-certbot-nginx
  - ufw

write_files:
  # Nginx configuration for code-server
  - path: /etc/nginx/sites-available/code-server.conf
    content: |
      server {
          listen 80;
          listen [::]:80;

          server_name ${domain_name};

          location / {
            proxy_pass http://localhost:8080/;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          }
      }
    permissions: '0644'
  
  # code-server systemd service
  - path: /lib/systemd/system/code-server.service
    content: |
      [Unit]
      Description=code-server
      After=nginx.service

      [Service]
      Type=simple
      Environment=PASSWORD=your_secure_password_here
      ExecStart=/usr/bin/code-server --bind-addr 127.0.0.1:8080 --user-data-dir /var/lib/code-server --auth password
      Restart=always
      User=ubuntu
      Group=ubuntu

      [Install]
      WantedBy=multi-user.target
    permissions: '0644'

runcmd:
  # Create code-server directory
  - mkdir -p /home/ubuntu/code-server
  - chown -R ubuntu:ubuntu /home/ubuntu

  # Download and install code-server (using latest version)
  - cd /home/ubuntu/code-server
  - wget -O code-server.tar.gz "$(curl -s https://api.github.com/repos/coder/code-server/releases/latest | grep 'browser_download_url.*linux-amd64.tar.gz' | cut -d '"' -f 4)"
  - tar -xzf code-server.tar.gz --strip-components=1
  - cp -r /home/ubuntu/code-server /usr/lib/code-server
  - ln -sf /usr/lib/code-server/bin/code-server /usr/bin/code-server

  # Create code-server data directory
  - mkdir -p /var/lib/code-server
  - chown -R ubuntu:ubuntu /var/lib/code-server

  # Configure firewall
  - ufw --force enable
  - ufw allow ssh
  - ufw allow http
  - ufw allow https

  # Configure Nginx
  - rm -f /etc/nginx/sites-enabled/default
  - ln -sf /etc/nginx/sites-available/code-server.conf /etc/nginx/sites-enabled/code-server.conf
  - nginx -t
  - systemctl restart nginx
  - systemctl enable nginx

  # Start and enable code-server
  - systemctl daemon-reload
  - systemctl start code-server
  - systemctl enable code-server

  # Clean up
  - rm -rf /home/ubuntu/code-server/code-server.tar.gz