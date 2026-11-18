#!/bin/bash
set -e

REGION="${AWS_REGION:-us-east-1}"
REPO_BACKEND="${REPO_BACKEND:-https://github.com/EddigarCuello/course-backend.git}"
REPO_FRONTEND="${REPO_FRONTEND:-https://github.com/EddigarCuello/course-frontend.git}"

if [ "$1" = "--destroy" ] || [ "$1" = "destroy" ]; then
  echo "Destruyendo toda la infraestructura con Terraform..."
  terraform destroy -auto-approve
  exit 0
fi

echo "1. Inicializando Terraform y creando repositorio Amazon ECR..."
terraform init
terraform apply -target=aws_ecr_repository.backend -auto-approve

ECR_URL=$(terraform output -raw ecr_repository_url)
ACCOUNT_ID=$(echo "$ECR_URL" | cut -d'.' -f1)

echo "2. Construyendo imagen Docker del backend y subiendo a ECR..."
rm -rf /tmp/vp-backend && git clone "$REPO_BACKEND" /tmp/vp-backend
if [ ! -f /tmp/vp-backend/Dockerfile ]; then
  cat <<'EOF' > /tmp/vp-backend/Dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install --omit=dev
COPY . .
EXPOSE 8080
CMD ["npm", "start"]
EOF
fi

aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"
docker build -t "$ECR_URL:latest" /tmp/vp-backend
docker push "$ECR_URL:latest"

echo "3. Desplegando infraestructura completa (ECS Fargate, RDS Multi-AZ, Serverless)..."
terraform apply -auto-approve

ALB_URL=$(terraform output -raw alb_http_url)
FRONTEND_BUCKET=$(terraform output -raw frontend_bucket_name)

if command -v npm >/dev/null 2>&1; then
  echo "4. Compilando y publicando Frontend SPA en S3..."
  rm -rf /tmp/vp-frontend && git clone "$REPO_FRONTEND" /tmp/vp-frontend
  (cd /tmp/vp-frontend && npm install --silent && VITE_API_URL="$ALB_URL" npm run build && aws s3 sync dist/ "s3://$FRONTEND_BUCKET/" --delete --region "$REGION")
fi

echo ""
echo "Despliegue completado. Salidas de Terraform:"
terraform output
