output "web_public_ip" {
  value = aws_instance.web.public_ip
}

output "app_public_ip" {
  value = aws_instance.app.public_ip
}

output "db_public_ip" {
  value = aws_instance.db.public_ip
}
