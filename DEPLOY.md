# Retail App — Deployment Guide

## Architecture Overview

```
GitHub → CodePipeline → CodeBuild → ECR → CodeDeploy (Blue/Green) → ECS Fargate
                                                 ↕
                                         RDS PostgreSQL (Private Subnet)
                                                 ↕
                                     ALB (Public) → ECS Tasks (Private)
```

## Project Structure

```
project/
├── app/
│   ├── backend/          # Node.js 20 + Express API
│   ├── frontend/         # React 18 SPA (served via nginx)
│   └── docker-compose.yml
├── terraform/
│   ├── backend-setup/    # S3 + DynamoDB for remote state (run once)
│   ├── modules/
│   │   ├── vpc/          # VPC, subnets, NAT, flow logs
│   │   ├── ecr/          # ECR repos + lifecycle policies
│   │   ├── rds/          # PostgreSQL + Secrets Manager
│   │   ├── alb/          # ALB + Blue/Green target groups
│   │   ├── ecs/          # ECS Cluster, Fargate service, autoscaling
│   │   ├── iam/          # All IAM roles
│   │   └── cicd/         # CodePipeline + CodeBuild + CodeDeploy
│   └── environments/
│       ├── dev/
│       ├── staging/
│       └── prod/
├── buildspec.yml         # CodeBuild instructions
├── appspec.yml           # CodeDeploy ECS spec
└── taskdef-template.json # ECS task definition template
```

## Prerequisites

- AWS CLI configured (`aws configure`)
- Terraform >= 1.6 installed
- Docker installed
- Node.js 20 installed

## Step 1 — Bootstrap Remote State (once only)

```bash
cd terraform/backend-setup
# Edit main.tf: replace variable "aws_account_id" with your account ID
terraform init
terraform apply -var="aws_account_id=$(aws sts get-caller-identity --query Account --output text)"
```

## Step 2 — Update terraform.tfvars

Edit each environment's `terraform.tfvars`:
```
github_repo = "yourname/your-repo"   # GitHub owner/repo
alert_email = "you@example.com"
```

Update the S3 backend bucket name in each `main.tf` backend block:
```
bucket = "retail-tfstate-YOUR_ACCOUNT_ID"
```

## Step 3 — Deploy Infrastructure (Dev)

```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

This provisions:
- VPC with public/private/DB subnets across 2 AZs
- NAT Gateways for private subnet egress
- ECR repositories (frontend + backend)
- RDS PostgreSQL with Secrets Manager
- ALB with Blue/Green target groups
- ECS Fargate cluster + service
- IAM roles (ECS, CodeBuild, CodePipeline, CodeDeploy)
- CodePipeline (Source → Build → Staging → Approve → Prod)

## Step 4 — Connect GitHub to CodePipeline

After `terraform apply`, complete the GitHub connection:
```bash
# Get the connection ARN from outputs
terraform output github_connection_arn

# In AWS Console: CodePipeline → Settings → Connections
# Find the pending connection and click "Update pending connection"
# Authorize the GitHub App
```

## Step 5 — Push Initial Images to ECR

```bash
# Get ECR URLs from terraform output
FRONTEND_REPO=$(terraform output -raw frontend_ecr_url)
BACKEND_REPO=$(terraform output -raw backend_ecr_url)
AWS_REGION="ca-central-1"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Build and push
docker build -t $FRONTEND_REPO:latest --build-arg REACT_APP_API_URL=/api app/frontend/
docker build -t $BACKEND_REPO:latest app/backend/
docker push $FRONTEND_REPO:latest
docker push $BACKEND_REPO:latest
```

## Step 6 — Update taskdef-template.json Placeholders

Replace these placeholders in `taskdef-template.json` with values from `terraform output`:

| Placeholder                    | Replace with                        |
|-------------------------------|-------------------------------------|
| `TASK_FAMILY_PLACEHOLDER`     | ECS task family name                |
| `EXECUTION_ROLE_ARN_PLACEHOLDER` | ECS execution role ARN           |
| `TASK_ROLE_ARN_PLACEHOLDER`   | ECS task role ARN                   |
| `CLUSTER_NAME_PLACEHOLDER`    | ECS cluster name                    |
| `DB_SECRET_ARN_PLACEHOLDER`   | Secrets Manager secret ARN          |

## Step 7 — Trigger the Pipeline

Push code to your `dev` branch. The pipeline automatically:
1. **Source** — pulls from GitHub
2. **Build** — runs tests, builds Docker images, pushes to ECR
3. **Deploy (Staging)** — Blue/Green deployment to ECS Fargate
4. **Approve** — sends SNS email; manually approve in Console
5. **Deploy (Prod)** — promoted to production

## Local Development

```bash
cd app
docker-compose up --build
```

- Frontend: http://localhost:80
- Backend API: http://localhost:3001
- Postgres: localhost:5432

## Rollback

Automatic rollback triggers on:
- ALB 5XX error rate alarm fires
- ECS CPU high alarm fires
- Deployment health check fails

Manual rollback via CLI:
```bash
aws deploy stop-deployment \
  --deployment-id d-XXXXXXXX \
  --auto-rollback-enabled
```

## Environment Differences

| Setting           | Dev           | Staging       | Prod          |
|-------------------|---------------|---------------|---------------|
| RDS Instance      | db.t3.micro   | db.t3.small   | db.r6g.large  |
| RDS Multi-AZ      | No            | Yes           | Yes           |
| ECS Desired Count | 1             | 2             | 3             |
| ECS Max Count     | 4             | 8             | 20            |
| Log Retention     | 7 days        | 14 days       | 90 days       |
| Deletion Protection | No          | No            | Yes           |
| Task CPU/Memory   | 512/1024      | 1024/2048     | 2048/4096     |
