output "rds_host" {
  description = "The endpoint of the RDS instance"
  value       = aws_db_instance.mysql.endpoint
}

output "vpc_connector_arn" {
  description = "The ARN of the VPC connector"
  value = aws_apprunner_vpc_connector.connector.arn
}