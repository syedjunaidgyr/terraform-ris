#!/bin/bash
set -euxo pipefail

LOG_FILE="/var/log/ris-bootstrap.log"
exec > >(tee -a "$LOG_FILE" | logger -t user-data -s 2>/dev/console) 2>&1

echo "===== Starting RIS Bootstrap Script ====="

dnf update -y
dnf install -y git unzip python3 python3-pip curl --allowerasing || true

set +x
GITHUB_USERNAME="${github_username}"
GITHUB_TOKEN="${github_token}"
export GITHUB_USERNAME
export GITHUB_TOKEN
set -x

NODE_MAJOR_VERSION="${node_major_version}"
if [ -z "$NODE_MAJOR_VERSION" ]; then
  NODE_MAJOR_VERSION="18"
fi
curl -fsSL "https://rpm.nodesource.com/setup_$NODE_MAJOR_VERSION.x" | bash -
dnf install -y nodejs
npm install -g pm2

if ! id -u "${app_user}" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash "${app_user}"
fi

APP_ROOT="/opt/ris-apps"
mkdir -p "$APP_ROOT"
chown -R "${app_user}:${app_user}" "$APP_ROOT"

get_public_ip() {
  local token=""
  local ip=""

  token=$(curl -s --max-time 2 -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" || true)
  if [ -n "$token" ]; then
    ip=$(curl -s --max-time 2 -H "X-aws-ec2-metadata-token: $token" "http://169.254.169.254/latest/meta-data/public-ipv4" || true)
  fi

  if [ -z "$ip" ]; then
    ip=$(curl -s --max-time 2 "http://169.254.169.254/latest/meta-data/public-ipv4" || true)
  fi

  if [ -z "$ip" ]; then
    ip=$(curl -s --max-time 4 "https://checkip.amazonaws.com" | tr -d '\n\r' || true)
  fi

  if [ -z "$ip" ]; then
    ip=$(hostname -I 2>/dev/null | awk '{print $1}' || true)
  fi

  if [ -z "$ip" ]; then
    ip="127.0.0.1"
  fi

  echo "$ip"
}

PUBLIC_IP="$(get_public_ip)"

RIS_BACKEND_URL="http://$PUBLIC_IP:${app_port}"
PACS_BACKEND_URL="http://$PUBLIC_IP:${pacs_service_port}"
TEMPLATE_BACKEND_URL="http://$PUBLIC_IP:${template_service_port}"
AI_BACKEND_URL="http://$PUBLIC_IP:${ai_service_port}"

configure_git_credentials() {
  if [ -n "$GITHUB_USERNAME" ] && [ -n "$GITHUB_TOKEN" ]; then
    set +x
    local user_home="/home/${app_user}"
    mkdir -p "$user_home"
    chown "${app_user}:${app_user}" "$user_home"
    cat <<EOF_CREDENTIALS >"$user_home/.git-credentials"
https://$${GITHUB_USERNAME}:$${GITHUB_TOKEN}@github.com
EOF_CREDENTIALS
    chmod 600 "$user_home/.git-credentials"
    chown "${app_user}:${app_user}" "$user_home/.git-credentials"
    runuser -l "${app_user}" -c "git config --global credential.helper store"
    set -x
  fi
}

configure_git_credentials

clone_or_update_repo() {
  local repo_url="$1"
  local destination="$2"

  if [ ! -d "$destination/.git" ]; then
    runuser -l "${app_user}" -c "git clone \"$repo_url\" \"$destination\""
  else
    runuser -l "${app_user}" -c "cd \"$destination\" && git fetch --all --prune && git reset --hard origin/main && git clean -fdx || true"
  fi
}

clone_or_update_repo "${repo_ris_backend}"           "$APP_ROOT/ris-backend"
clone_or_update_repo "${repo_ris_frontend}"          "$APP_ROOT/ris-frontend"
clone_or_update_repo "${repo_pacs_frontend}"         "$APP_ROOT/pacs_frontend"
clone_or_update_repo "${repo_ris_template}"          "$APP_ROOT/ris-template"
clone_or_update_repo "${repo_openai_image_analysis}" "$APP_ROOT/openai-image-analysis"
clone_or_update_repo "${repo_orthanc}"               "$APP_ROOT/orthanc"

cat <<EOF >"$APP_ROOT/ris-backend/.env"
DB_HOST=${db_host}
DB_PORT=${db_port}
DB_NAME=${db_name}
DB_USER=${db_username}
DB_PASSWORD=${db_password}
JWT_SECRET=${ris_jwt_secret}
JWT_EXPIRES_IN=24h
PORT=${app_port}
NODE_ENV=production
PACS_API_BASE=$PACS_BACKEND_URL
EOF

cat <<EOF >"$APP_ROOT/ris-frontend/.env.local"
NEXT_PUBLIC_API_URL=$RIS_BACKEND_URL
NEXT_PUBLIC_PACS_API_URL=$PACS_BACKEND_URL
NEXT_PUBLIC_AI_API_URL=$AI_BACKEND_URL
NEXT_PUBLIC_TEMPLATE_API_URL=$TEMPLATE_BACKEND_URL
EOF

cat <<EOF >"$APP_ROOT/pacs_frontend/.env.local"
NEXT_PUBLIC_API_BASE_URL=$PACS_BACKEND_URL
Ris_backend=$RIS_BACKEND_URL
Pacs_backend=$PACS_BACKEND_URL
NEXT_PUBLIC_RIS_API_BASE_URL=$TEMPLATE_BACKEND_URL
EOF

cat <<EOF >"$APP_ROOT/ris-template/.env"
PORT=${template_service_port}
DB_HOST=${db_host}
DB_USER=${db_username}
DB_PASSWORD=${db_password}
DB_NAME=ris-templates
DB_PORT=${db_port}
MYSQL_HOST=${db_host}
MYSQL_USER=${db_username}
MYSQL_PASSWORD=${db_password}
MYSQL_DATABASE=ris-templates
EOF

cat <<EOF >"$APP_ROOT/openai-image-analysis/.env"
PORT=${ai_service_port}
OPENAI_API_KEY=${openai_api_key}
EOF

chown -R "${app_user}:${app_user}" "$APP_ROOT"

APP_SETUP_SCRIPT="/tmp/ris-app-bootstrap.sh"
cat <<EOF_APP_SETUP >"$APP_SETUP_SCRIPT"
#!/bin/bash
set -euxo pipefail

retry() {
  local -r max_attempts="\$1"; shift
  local attempt=1
  until "\$@"; do
    if [ "\$attempt" -ge "\$max_attempts" ]; then
      echo "Command failed after \$attempt attempts: \$*"
      return 1
    fi
    echo "Retrying (\$attempt/\$max_attempts) in 10s: \$*"
    attempt=\$((attempt + 1))
    sleep 10
  done
  return 0
}

load_env_if_exists() {
  local env_file="\$1"
  if [ -f "\$env_file" ]; then
    set -a
    # shellcheck disable=SC1090
    source "\$env_file"
    set +a
  fi
}

cd "$APP_ROOT/ris-backend"
load_env_if_exists ".env"
retry 3 npm install
(pm2 delete ris-backend >/dev/null 2>&1 || true)
pm2 start npm --name ris-backend -- start || true

cd "$APP_ROOT/ris-frontend"
load_env_if_exists ".env.local"
retry 3 npm install
NODE_ENV= npm install --save typescript @types/react @types/node
npm run build
(pm2 delete ris-frontend >/dev/null 2>&1 || true)
PORT=${frontend_port} pm2 start npm --name ris-frontend -- start || true

cd "$APP_ROOT/ris-template"
load_env_if_exists ".env"
retry 3 npm install
(pm2 delete ris-template >/dev/null 2>&1 || true)
PORT=${template_service_port} pm2 start npm --name ris-template -- start || true

cd "$APP_ROOT/openai-image-analysis"
load_env_if_exists ".env"
if [ -z "$${OPENAI_API_KEY:-}" ]; then
  echo "OPENAI_API_KEY is not set; skipping openai-image-analysis service startup."
else
  python3 -m venv venv
  source venv/bin/activate
  retry 3 pip install --upgrade pip
  retry 3 pip install -r requirements.txt
  (pm2 delete openai-image-analysis >/dev/null 2>&1 || true)
  pm2 start ./venv/bin/python --name openai-image-analysis -- app.py || true
  deactivate || true
fi

cd "$APP_ROOT/orthanc"
load_env_if_exists ".env"
retry 3 npm install
(pm2 delete orthanc-parser >/dev/null 2>&1 || true)
pm2 start dicom-parser-correct-fix.js --name orthanc-parser || true
pm2 save || true
pm2 resurrect || true
sleep 2
pm2 list || true
EOF_APP_SETUP

chmod +x "$APP_SETUP_SCRIPT"
chown "${app_user}:${app_user}" "$APP_SETUP_SCRIPT"
runuser -l "${app_user}" -c "bash \"$APP_SETUP_SCRIPT\""
rm -f "$APP_SETUP_SCRIPT"

runuser -l "${app_user}" -c "pm2 startup systemd -u ${app_user} --hp /home/${app_user} >/dev/null 2>&1 || true"
runuser -l "${app_user}" -c "pm2 save >/dev/null 2>&1 || true"
runuser -l "${app_user}" -c "pm2 resurrect >/dev/null 2>&1 || true"

echo "===== RIS Bootstrap Complete Successfully ====="
