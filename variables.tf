variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "prefix" {
  type    = string
  default = "vacacionalpag"
}

variable "proyecto" {
  type    = string
  default = "VacacionalPag"
}

variable "ambiente" {
  type    = string
  default = "Produccion"
}

variable "responsable" {
  type    = string
  default = "AndersonCuadrado"
}

variable "expiracion" {
  type    = string
  default = "2026-11-30"
}

variable "db_password" {
  type      = string
  sensitive = true
  default   = "PostgresSecurePass2026!"
}

variable "admin_password" {
  type      = string
  sensitive = true
  default   = "AdminSecurePass2026!"
}
