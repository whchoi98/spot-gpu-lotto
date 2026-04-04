# terraform/modules/fsx/outputs.tf
output "file_system_id" {
  value = aws_fsx_lustre_file_system.this.id
}

output "dns_name" {
  value = aws_fsx_lustre_file_system.this.dns_name
}

output "mount_name" {
  value = aws_fsx_lustre_file_system.this.mount_name
}
