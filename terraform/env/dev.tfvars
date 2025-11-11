project     = "ris"
environment = "dev"
region      = "ap-south-1"
aws_profile = null

allowed_ssh_cidrs = [
  "0.0.0.0/0"
]

ssh_key_name = "your-ec2-keypair-name"

app_directory = "/opt/ris/current"
app_user      = "ec2-user"

app_port              = 3000
frontend_port         = 3002
pacs_service_port     = 3001
template_service_port = 6011
ai_service_port       = 8000

repo_ris_backend           = "https://github.com/zaenAbdulali/ris-backend.git"
repo_ris_frontend          = "https://github.com/zaenAbdulali/ris-frontend.git"
repo_pacs_frontend         = "https://github.com/shanmukhaPriyagyr/pacs_frontend.git"
repo_ris_template          = "https://github.com/Niyam23/RIS-Backend-Template.git"
repo_openai_image_analysis = "https://github.com/zaenAbdulali/openai-image-analysis.git"
repo_orthanc               = "https://github.com/zaenAbdulali/orthanc.git"

github_username = ""
github_token    = ""

ris_jwt_secret = "change-me"
openai_api_key = ""

db_name     = "ris"
db_username = "ris_admin"
db_password = "change-me"

allowed_origins = [
  "http://localhost:3000"
]

