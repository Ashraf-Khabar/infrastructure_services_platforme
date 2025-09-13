output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_eip.app.public_ip
}

output "application_url" {
  description = "URL of the deployed application"
  value       = "http://${aws_eip.app.public_ip}:5000"
}

output "ssh_connection_command" {
  description = "SSH connection command"
  value       = "ssh -i ~/.ssh/id_rsa ubuntu@${aws_eip.app.public_ip}"
}

output "vpc_id" {
  description = "ID of the VPC used"
  value       = data.aws_vpc.existing.id
}

output "subnet_id" {
  description = "ID of the subnet used"
  value       = data.aws_subnet.selected.id
}