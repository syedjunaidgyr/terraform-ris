## Deployment Workflow

The GitHub Actions workflow `deploy-backend.yml` packages the `ris-backend`
application, uploads it to the EC2 instance created by Terraform, and restarts
the service with `pm2`.

### Required GitHub Secrets

- `EC2_HOST`: Public DNS or IP of the target EC2 instance
- `EC2_USER`: SSH username (e.g. `ec2-user`)
- `EC2_SSH_KEY`: Private key corresponding to the instance key pair (PEM format)

Optional additional secrets can be used for database credentials that will be
placed in the remote `.env` file outside of version control.

### First-Time Server Prep

1. Run `terraform apply` to provision the infrastructure.
2. SSH to the instance and populate `/opt/ris/current/.env` with production
   environment variables.
3. Trigger the GitHub Actions workflow manually (or push to `main`) to deploy.

`pm2` will keep the process running across restarts. Future deployments update
the symlink at `/opt/ris/current`, reinstall dependencies, and restart the
process through `pm2`.

