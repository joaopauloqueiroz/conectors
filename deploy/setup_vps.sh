#!/bin/bash
set -e

REPO_URL="https://github.com/joaopauloqueiroz/conectors.git"
BRANCH="claude/create-ruby-api-server-Fxn5C"
APP_DIR="/var/www/conectors"
APP_USER="deploy"
RUBY_VERSION="3.3.6"
PORT=9292

echo "==> [1/7] Atualizando sistema..."
apt-get update -y && apt-get upgrade -y

echo "==> [2/7] Instalando dependências do sistema..."
apt-get install -y git curl build-essential libssl-dev libreadline-dev \
  zlib1g-dev libsqlite3-dev nginx ufw

echo "==> [3/7] Criando usuário deploy..."
if ! id "$APP_USER" &>/dev/null; then
  useradd -m -s /bin/bash "$APP_USER"
fi

echo "==> [4/7] Instalando rbenv + Ruby $RUBY_VERSION para o usuário deploy..."
su - "$APP_USER" -c "
  if [ ! -d ~/.rbenv ]; then
    git clone https://github.com/rbenv/rbenv.git ~/.rbenv
    git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
    echo 'export PATH=\"\$HOME/.rbenv/bin:\$PATH\"' >> ~/.bashrc
    echo 'eval \"\$(rbenv init -)\"' >> ~/.bashrc
  fi
  export PATH=\"\$HOME/.rbenv/bin:\$PATH\"
  eval \"\$(rbenv init -)\"
  rbenv install -s $RUBY_VERSION
  rbenv global $RUBY_VERSION
  gem install bundler --no-document
"

echo "==> [5/7] Clonando repositório e instalando gems..."
if [ -d "$APP_DIR" ]; then
  su - "$APP_USER" -c "cd $APP_DIR && git pull origin $BRANCH"
else
  su - "$APP_USER" -c "git clone -b $BRANCH $REPO_URL $APP_DIR"
fi

su - "$APP_USER" -c "
  export PATH=\"\$HOME/.rbenv/bin:\$PATH\"
  eval \"\$(rbenv init -)\"
  cd $APP_DIR
  bundle install --without development test
"

echo "==> [6/7] Configurando serviço systemd..."
cat > /etc/systemd/system/conectors.service <<EOF
[Unit]
Description=Conectors Ruby API Server
After=network.target

[Service]
Type=simple
User=$APP_USER
WorkingDirectory=$APP_DIR
Environment=RACK_ENV=production
ExecStart=/home/$APP_USER/.rbenv/shims/bundle exec puma config.ru -p $PORT -e production
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable conectors
systemctl restart conectors

echo "==> [7/7] Configurando Nginx como proxy reverso..."
cat > /etc/nginx/sites-available/conectors <<EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

ln -sf /etc/nginx/sites-available/conectors /etc/nginx/sites-enabled/conectors
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx

echo "==> Configurando firewall..."
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw --force enable

echo ""
echo "============================================"
echo " Deploy concluido!"
echo " API disponivel em: http://82.25.75.171"
echo " Health check:      http://82.25.75.171/health"
echo "============================================"
