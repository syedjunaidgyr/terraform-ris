#!/bin/bash
set -euxo pipefail

exec > >(tee -a "/var/log/ris-bootstrap.log" | logger -t user-data -s 2>/dev/console) 2>&1

dnf update -y
dnf install -y git unzip curl python3 python3-pip

curl -fsSL "https://rpm.nodesource.com/setup_${node_major_version}.x" | bash -
dnf install -y nodejs
npm install -g pm2

if ! id -u "${app_user}" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash "${app_user}"
fi

APP_ROOT="/opt/ris-apps"
BACKEND_DIR="$${APP_ROOT}/ris-backend"
FRONTEND_DIR="$${APP_ROOT}/ris-frontend"
PACS_FRONTEND_DIR="$${APP_ROOT}/pacs_frontend"
TEMPLATE_DIR="$${APP_ROOT}/ris-template"
AI_DIR="$${APP_ROOT}/openai-image-analysis"
ORTHANC_DIR="$${APP_ROOT}/orthanc"

mkdir -p "$${APP_ROOT}"
chown -R "${app_user}:${app_user}" "$${APP_ROOT}"

PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || echo "127.0.0.1")
RIS_BACKEND_URL="http://${PUBLIC_IP}:${app_port}"
PACS_BACKEND_URL="http://${PUBLIC_IP}:${pacs_service_port}"
TEMPLATE_BACKEND_URL="http://${PUBLIC_IP}:${template_service_port}"
AI_BACKEND_URL="http://${PUBLIC_IP}:${ai_service_port}"

clone_or_update_repo() {
  local repo_url="$1"
  local destination="$2"
  if [ ! -d "$${destination}/.git" ]; then
    runuser -l "${app_user}" -c "git clone $${repo_url} $${destination}"
  else
    runuser -l "${app_user}" -c "cd $${destination} && git fetch --all && git pull --ff-only || true"
  fi
}

clone_or_update_repo "${repo_ris_backend}" "$${BACKEND_DIR}"
clone_or_update_repo "${repo_ris_frontend}" "$${FRONTEND_DIR}"
clone_or_update_repo "${repo_pacs_frontend}" "$${PACS_FRONTEND_DIR}"
clone_or_update_repo "${repo_ris_template}" "$${TEMPLATE_DIR}"
clone_or_update_repo "${repo_openai_image_analysis}" "$${AI_DIR}"
clone_or_update_repo "${repo_orthanc}" "$${ORTHANC_DIR}"

cat <<EOF >"$${BACKEND_DIR}/.env"
# Database Configuration
DB_HOST=${db_host}
DB_PORT=${db_port}
DB_NAME=${db_name}
DB_USER=${db_username}
DB_PASSWORD=${db_password}

# JWT Configuration
JWT_SECRET=${ris_jwt_secret}
JWT_EXPIRES_IN=24h

# Server Configuration
PORT=${app_port}
NODE_ENV=production

# Email Configuration
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=
SMTP_PASS=

# SMS Configuration (Twilio)
TWILIO_ACCOUNT_SID=
TWILIO_AUTH_TOKEN=
TWILIO_PHONE_NUMBER=

# DICOM Configuration
DICOM_AE_TITLE=RIS_SERVER
DICOM_PORT=104

# File Upload
MAX_FILE_SIZE=50MB
UPLOAD_PATH=./uploads

PACS_API_BASE=${PACS_BACKEND_URL}
EOF

cat <<EOF >"$${FRONTEND_DIR}/.env"
#ris backend api
NEXT_PUBLIC_API_URL=${RIS_BACKEND_URL}

#pacs api
NEXT_PUBLIC_PACS_API_URL=${PACS_BACKEND_URL}

#ai api
NEXT_PUBLIC_AI_API_URL=${AI_BACKEND_URL}

# templates api
NEXT_PUBLIC_TEMPLATE_API_URL=${TEMPLATE_BACKEND_URL}
EOF

cat <<EOF >"$${PACS_FRONTEND_DIR}/.env.local"
# API_BASE_URL=http://localhost:3000
NEXT_PUBLIC_API_BASE_URL=${PACS_BACKEND_URL}
Ris_backend=${RIS_BACKEND_URL}
Pacs_backend=${PACS_BACKEND_URL}
NEXT_PUBLIC_RIS_API_BASE_URL=${TEMPLATE_BACKEND_URL}
EOF

cat <<EOF >"$${TEMPLATE_DIR}/.env"
PORT=${template_service_port}
DB_HOST=${db_host}
DB_USER=${db_username}
DB_PASSWORD=${db_password}
DB_NAME=ris-templates
DB_PORT=${db_port}
EOF

cat <<EOF >"$${AI_DIR}/.env"
OPENAI_API_KEY=${openai_api_key}
EOF

chown -R "${app_user}:${app_user}" "$${APP_ROOT}"

runuser -l "${app_user}" -c "cd $${BACKEND_DIR} && npm install && (pm2 delete ris-backend >/dev/null 2>&1 || true) && pm2 start npm --name \"ris-backend\" -- start"
runuser -l "${app_user}" -c "cd $${FRONTEND_DIR} && npm install && npm run build && (pm2 delete ris-frontend >/dev/null 2>&1 || true) && PORT=${frontend_port} pm2 start npm --name \"ris-frontend\" -- run start"
runuser -l "${app_user}" -c "cd $${TEMPLATE_DIR} && npm install && (pm2 delete ris-template >/dev/null 2>&1 || true) && PORT=${template_service_port} pm2 start npm --name \"ris-template\" -- start"
runuser -l "${app_user}" -c "cd $${AI_DIR} && python3 -m venv venv && source venv/bin/activate && pip install --upgrade pip && pip install -r requirements.txt && (pm2 delete openai-image-analysis >/dev/null 2>&1 || true) && pm2 start ./venv/bin/python --name \"openai-image-analysis\" -- app.py"
runuser -l "${app_user}" -c "cd $${ORTHANC_DIR} && npm install && (pm2 delete orthanc-parser >/dev/null 2>&1 || true) && pm2 start dicom-parser-correct-fix.js --name \"orthanc-parser\""

pm2 startup systemd -u "${app_user}" --hp "/home/${app_user}"
mkdir -p "/etc/systemd/system/pm2-${app_user}.service.d"
cat <<'EOF' >/etc/systemd/system/pm2-${app_user}.service.d/override.conf
[Service]
Environment=PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin
EOF

systemctl daemon-reload
runuser -l "${app_user}" -c "pm2 save"

echo "Bootstrap complete."

