# Terraform Infrastructure

This folder provisions the core AWS infrastructure required to run the RIS
applications without Docker and manages the Node.js backend with `pm2`.

## What Gets Created

- Dedicated VPC with public subnets, internet gateway, and routing
- Security group allowing SSH, HTTP/HTTPS, and the configurable application port
- EC2 instance (Amazon Linux 2023) with SSM access
- Instance bootstrap script that installs Node.js, Git, and `pm2`, then prepares
  the application directory structure for later deployments
- Amazon RDS MySQL instance secured to accept traffic only from the application
  security group (private by default, optional Terraform-driven seeding)

## Prerequisites

1. Terraform >= 1.5
2. AWS credentials configured locally (via named profile, environment variables,
   or SSO)
3. An existing EC2 key pair name in the target account (for SSH access)

## Configuration Steps

Follow these steps once per environment (dev, staging, prod, etc.).

1. **Set up AWS credentials**
   - Configure the AWS CLI with a profile that has permissions for VPC, EC2, RDS, SSM, IAM.
   - Example: `aws configure --profile ris-dev`
   - For CI/CD, store access keys or use OIDC/role assumptions in GitHub Secrets.

2. **Choose or create the Terraform state backend (optional but recommended)**
   - Copy `backend.tf.example` to `backend.tf`.
   - Replace placeholder bucket/table/profile values with your own S3 bucket and DynamoDB lock table.
   - Skip this step to keep local state (`terraform.tfstate`).

3. **Create an environment variable file**
   - Copy `env/dev.tfvars.example` to a new file (e.g. `env/dev.tfvars`, `env/prod.tfvars`).
   - Update the file with environment-specific settings:
     - `region`: AWS region to deploy into.
     - `aws_profile`: matches the configured CLI profile (or leave blank for default).
     - `ssh_key_name`: existing EC2 key pair in that region.
     - `allowed_ssh_cidrs`: lock down SSH access (e.g. office IP).
     - `instance_type`, `app_port`, `node_major_version`, etc.
     - Database settings (`db_*` variables). Keep `db_password` out of source control:
       export it before running Terraform, e.g. `export TF_VAR_db_password='StrongPassword!'`.
     - Set `db_seed_enabled = true` only if you want Terraform to run the SQL seed files automatically and your workstation has network access plus the `mysql` CLI.
     - Legacy single-file variable `db_seed_sql_file` is still accepted; when present it is merged into `db_seed_sql_files`.

4. **Review optional toggles**
   - Enable Multi-AZ (`db_multi_az = true`) and increase storage for production workloads.
   - Set `db_publicly_accessible = false` to keep RDS private (default).
   - Adjust `allowed_ssh_cidrs` to trusted ranges; leave empty to disable SSH exposure.

### Example `env/dev.tfvars`

```hcl
project                = "ris"
environment            = "dev"
region                 = "us-east-1"
aws_profile            = "ris-dev"
ssh_key_name           = "ris-dev-key"
allowed_ssh_cidrs      = ["203.0.113.15/32"]
app_port               = 3000
instance_type          = "t3.medium"
node_major_version     = "18"
pm2_version            = "latest"
app_directory          = "/opt/ris/current"
db_name                = "ris"
db_username            = "ris_admin"
# db_password set through TF_VAR_db_password environment variable
db_seed_enabled        = false
# db_seed_sql_files    = ["../database/ris.sql", "../database/ris-templates.sql"]
```

## Deployment Steps

> All commands are run from the repository root unless noted otherwise.

1. **Enter the Terraform directory**
   ```bash
   cd /Users/gyrit/Documents/terraform-ris/terraform
   ```

2. **Export sensitive variables (if not in tfvars)**
   ```bash
   export TF_VAR_db_password='StrongPassword!'
   ```
   Repeat for any other sensitive variable you do not want stored in tfvars.

3. **Initialize Terraform**
   ```bash
   terraform init
   ```
   This downloads providers and configures the remote backend if `backend.tf` is present.

4. **Review the execution plan**
   ```bash
   terraform plan -var-file=env/dev.tfvars
   ```
   - Add `-out=plan.out` if you want to save the plan for later application.
   - Use the appropriate tfvars file for each environment.

5. **Apply the infrastructure**
   ```bash
   terraform apply -var-file=env/dev.tfvars
   ```
   - Confirm when prompted (or use `-auto-approve`).
   - Terraform outputs the EC2 IP/DNS and the RDS endpoint/port for reference.

6. **Populate application secrets on the EC2 instance**
   - Connect via SSM Session Manager or SSH (`ssh -i /path/to/key.pem ec2-user@<public-ip>`).
   - Create or update `/opt/ris/current/.env` with environment variables required by the Node.js backend.

7. **Trigger application deployment**
   - Push to `main` (or manually trigger) the `Deploy Backend` GitHub Actions workflow.
   - The workflow uploads the latest `ris-backend` build, runs `npm ci --omit=dev`, and restarts the PM2 process.

8. **Verify**
   - Confirm the backend is running: `pm2 status`, `curl http://<public-ip>:3000/health`, or via your frontend.
   - Check the RDS instance via MySQL Workbench using the output endpoint, port, and credentials.

9. **Subsequent changes**
   - Modify tfvars or Terraform code.
   - Re-run steps 3–5 for plan/apply.
   - CI/CD redeploys app code automatically on push.

## Related Application Repositories

Clone the application stacks alongside this Terraform project so CI/CD workflows
have access to the source code they deploy:

| Service                    | Stack / Purpose                          | Repository (SSH)                                           |
|---------------------------|-------------------------------------------|------------------------------------------------------------|
| `ris-backend`             | Node.js (Sequelize) backend API           | `git@github.com:zaenAbdulali/ris-backend.git`              |
| `ris-frontend`            | Next.js RIS frontend                      | `git@github.com:zaenAbdulali/ris-frontend.git`             |
| `pacs_frontend`           | Next.js PACS viewer frontend              | `git@github.com:shanmukhaPriyagyr/pacs_frontend.git`       |
| `orthanc`                 | DICOM/Orthanc tooling and integrations    | `git@github.com:zaenAbdulali/orthanc.git`                  |
| `openai-image-analysis`   | Python imaging AI service                 | `git@github.com:zaenAbdulali/openai-image-analysis.git`    |
| `RIS-Backend-Template`    | Legacy backend reference implementation   | `git@github.com:Niyam23/RIS-Backend-Template.git`          |

Example cloning workflow:

```bash
mkdir -p ~/Documents/terraform-ris
cd ~/Documents/terraform-ris

git clone git@github.com:zaenAbdulali/ris-backend.git
git clone git@github.com:zaenAbdulali/ris-frontend.git
git clone git@github.com:shanmukhaPriyagyr/pacs_frontend.git
git clone git@github.com:zaenAbdulali/orthanc.git
git clone git@github.com:zaenAbdulali/openai-image-analysis.git
git clone git@github.com:Niyam23/RIS-Backend-Template.git
```

## Deployment Flow with PM2

1. Terraform creates and boots the EC2 instance.
2. User data installs Node.js, global `pm2`, and prepares `/opt/ris/current`.
3. CI/CD pipeline (see `.github/workflows`) connects via SSM or SSH, syncs the
   application code, installs dependencies, and restarts the process with
   `pm2 start ecosystem.config.js --env production`.
4. `pm2 save` ensures process resurrection on reboot.

## Database Seeding

The RDS instance is provisioned empty by default. To automatically apply one or
more SQL files (for example `database/ris.sql` and `database/ris-templates.sql`)
set the following variables (via TFVARS or CLI flags):

```hcl
db_seed_enabled  = true
db_seed_sql_files = [
  "../database/ris.sql",
  "../database/ris-templates.sql",
] # paths relative to the terraform/ directory
# db_seed_sql_file can still be set for backward compatibility but will be ignored when the list above is populated.
# db_engine_version can be left empty to let AWS choose the latest supported MySQL 8.x release.
```

When seeding is enabled Terraform will:
- Require the `mysql` CLI to be installed on the machine running `terraform apply`
- Connect to the new RDS endpoint after creation
- Execute each SQL file in order (and re-run when a file’s checksum changes)

If you prefer to keep Terraform non-interactive or are running from a machine
without direct network access to the RDS instance, leave seeding disabled and
apply the SQL manually from the EC2 host or another trusted environment.

## Remote State (Optional)

To use remote backend (e.g., S3 + DynamoDB) copy `backend.tf.example` and fill
in bucket/table details before running `terraform init`.

