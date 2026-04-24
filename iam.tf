# ================================================================
# IAM — AWS Academy no permite crear roles (iam:CreateRole bloqueado)
# Se usa el rol LabRole preexistente para todas las tasks de ECS
# ================================================================

data "aws_iam_role" "lab_role" {
  name = "LabRole"
}
