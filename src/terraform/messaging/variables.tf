variable "db_host" {
  description = "The endpoint of the RDS instance"
  type        = string
}

variable "rds_root_user" {
  description = "The username for the RDS instance"
  type        = string
}

variable "rds_root_pass" {
  description = "The pass for the RDS instance"
  type        = string
}

variable "rds_db" {
  description = "The name of the RDS database"
  type        = string
}