#!/bin/bash
set -euxo pipefail

exec > >(tee -a "/var/log/ris-bootstrap.log" | logger -t user-data -s 2>/dev/console) 2>&1

echo "Updating system packages..."
dnf update -y

echo "Installing utilities..."
dnf install -y git unzip

echo "Installing Node.js ${node_major_version}.x..."
curl -fsSL "https://rpm.nodesource.com/setup_${node_major_version}.x" | bash -
dnf install -y nodejs

echo "Installing pm2 (${pm2_version})..."
if [ "${pm2_version}" = "latest" ]; then
  npm install -g pm2
else
  npm install -g "pm2@${pm2_version}"
fi

if ! id -u "${app_user}" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash "${app_user}"
fi

APP_ROOT="$(dirname "${app_directory}")"
mkdir -p "$${APP_ROOT}"
mkdir -p "$${APP_ROOT}/releases"
mkdir -p "${app_directory}"
chown -R "${app_user}:${app_user}" "$${APP_ROOT}"

cat <<'EOF' >/etc/profile.d/ris_app.sh
export NODE_ENV=${environment}
export APP_ROOT=${app_directory}
export APP_PORT=${app_port}
EOF

chmod 0644 /etc/profile.d/ris_app.sh

pm2 startup systemd -u "${app_user}" --hp "/home/${app_user}"

mkdir -p "/etc/systemd/system/pm2-${app_user}.service.d"

cat <<'EOF' >/etc/systemd/system/pm2-${app_user}.service.d/override.conf
[Service]
Environment=PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin
EOF

systemctl daemon-reload

cat <<'EOF' >"${app_directory}/README-bootstrap.txt"
The application code should be deployed to ${app_directory}.
After deploying the Node.js application run:

su - ${app_user}
cd ${app_directory}
npm install
pm2 start ecosystem.config.js --env ${environment}
pm2 save
EOF

chown -R "${app_user}:${app_user}" "$${APP_ROOT}"

echo "Bootstrap complete."

