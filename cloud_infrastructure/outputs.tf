output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_eip.app.public_ip
}

output "application_url" {
  description = "URL of the deployed application"
  value       = "http://${aws_eip.app.public_ip}:5000"
}