# Le decimos a Terraform que vamos a usar AWS como proveedor
# y qué versión mínima del plugin de AWS queremos usar.
# Terraform descargará este plugin automáticamente cuando ejecutes "terraform init"

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configuramos el proveedor AWS con credenciales temporales de AWS Academy.
# Las credenciales se definen en credentials.tf — actualiza ese archivo
# al inicio de cada sesión en AWS Academy Learner Lab.
# La región us-east-1 es obligatoria en AWS Academy.

provider "aws" {
  region     = "us-east-1"
  access_key = local.aws_access_key
  secret_key = local.aws_secret_key
  token      = local.aws_session_token
}