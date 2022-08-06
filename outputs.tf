output "public_ip"{
    value = try(aws_instance.ec2_sonarqube.public_ip, "")
}

output "rds_endpoint" {
  value = "${aws_db_instance.postgresql-instance.endpoint}"
}

output "rds_username" {
    value = "${aws_db_instance.postgresql-instance.username}"
}

output "rds_password" {
    sensitive = true
    value = "${aws_db_instance.postgresql-instance.password}"
}

output "rds_db_name" {
    value = "${aws_db_instance.postgresql-instance.db_name}"
}

