# VacacionalPag - Infraestructura AWS con Terraform

Este repositorio contiene la infraestructura como código (IaC) para el despliegue de **VacacionalPag** en Amazon Web Services (AWS) utilizando Terraform.

## Componentes y Arquitectura
- **Red y Conectividad (`network.tf`)**: VPC, subredes públicas y privadas, Internet Gateway y tablas de enrutamiento.
- **Base de Datos (`database.tf`)**: Instancia de base de datos relacional (PostgreSQL).
- **Cómputo en Contenedores (`ecs.tf`)**: Clúster de ECS Fargate, definiciones de tareas y servicios.
- **Funciones Serverless (`serverless.tf`)**: Lambdas y recursos asociados.
- **Almacenamiento y Seguridad (`security_storage.tf`)**: Buckets S3, roles y políticas IAM, Security Groups.
- **Variables y Configuración (`variables.tf`, `versions.tf`, `outputs.tf`)**: Parámetros parametrizables del proyecto.

## Despliegue
Para desplegar la infraestructura, ejecutar:
```bash
./deploy.sh
```
O manualmente:
```bash
terraform init
terraform plan
terraform apply
```
