output "ip-address-ec2" {
    value = aws_instance.web.public_ip
}

output "bucket-name" {
    value = aws_s3_bucket.airflow-bucket.id
}

output "postgress-db" {
    value = aws_db_instance.airflow-ddbb.endpoint
}