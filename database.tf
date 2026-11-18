resource "aws_db_subnet_group" "postgres" {
  name        = "${var.prefix}-db-subnets"
  subnet_ids  = [aws_subnet.priv_db_a.id, aws_subnet.priv_db_b.id]
  description = "Subredes privadas Multi-AZ para RDS VacacionalPag"
}

resource "aws_db_instance" "postgres" {
  identifier              = "${var.prefix}-pg-multiaz"
  engine                  = "postgres"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  db_name                 = "course_ecommerce_db"
  username                = "course_app"
  password                = var.db_password
  multi_az                = true
  db_subnet_group_name    = aws_db_subnet_group.postgres.name
  vpc_security_group_ids  = [aws_security_group.db.id]
  publicly_accessible     = false
  backup_retention_period = 1
  skip_final_snapshot     = true
  delete_automated_backups = true
}
