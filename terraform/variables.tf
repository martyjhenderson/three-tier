variable "database_password" {
  type    = string
  default = ""
}

variable "database_user" {
  type    = string
  default = "pg_superuser"
}

variable "cluster-name" {
  default = "mjh-demo-cluster"
  type    = string
}