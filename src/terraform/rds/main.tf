# Create a VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true

}

resource "aws_vpc_endpoint" "sns" {
  vpc_id = aws_vpc.main.id
  service_name = "com.amazonaws.eu-central-1.sns"
  auto_accept = true
  subnet_ids = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]
  security_group_ids = [aws_security_group.rds_sg.id] 
  vpc_endpoint_type = "Interface"
}

# Create a VPC connector for App Runner
resource "aws_apprunner_vpc_connector" "connector" {
  vpc_connector_name = "dbconnector"
  subnets            = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]
  security_groups    = [aws_security_group.rds_sg.id]
}

# Create subnets
resource "aws_subnet" "subnet1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-central-1a"  # Change to your desired availability zone
}

resource "aws_subnet" "subnet2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-central-1b"  # Change to your desired availability zone
}

# Create a security group
resource "aws_security_group" "rds_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create a DB subnet group
resource "aws_db_subnet_group" "main" {
  name       = "main"
  subnet_ids = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]

  tags = {
    Name = "Main DB subnet group"
  }
}

# Create an RDS MySQL instance with IAM authentication enabled
resource "aws_db_instance" "mysql" {
  allocated_storage    = 10
  db_name              = "shopdb"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  username             = var.rds_root_user
  password             = var.rds_root_pass
  db_subnet_group_name = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot  = true

  # Enable IAM database authentication
  iam_database_authentication_enabled = true

  tags = {
    Name = "MySQL RDS Instance"
  }
}

resource "aws_secretsmanager_secret" "rds_secret" {
  name = "rds_secret"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "rds_secret_version" {
  secret_id     = aws_secretsmanager_secret.rds_secret.id
  secret_string = jsonencode({
    username = aws_db_instance.mysql.username,
    password = aws_db_instance.mysql.password
  })
  
}

# Output the RDS endpoint
output "rds_endpoint" {
  value = aws_db_instance.mysql.endpoint
}