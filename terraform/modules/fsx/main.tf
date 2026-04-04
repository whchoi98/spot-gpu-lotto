# terraform/modules/fsx/main.tf

resource "aws_fsx_lustre_file_system" "this" {
  storage_capacity   = var.storage_capacity
  subnet_ids         = [var.subnet_id]
  security_group_ids = var.security_group_ids
  deployment_type    = "SCRATCH_2"
  storage_type       = "SSD"
  auto_import_policy = "NEW_CHANGED_DELETED"

  tags = { Name = "${var.name}-fsx" }
}

resource "aws_fsx_data_repository_association" "this" {
  file_system_id       = aws_fsx_lustre_file_system.this.id
  data_repository_path = var.s3_import_path
  file_system_path     = "/data"

  s3 {
    auto_export_policy {
      events = ["NEW", "CHANGED", "DELETED"]
    }
    auto_import_policy {
      events = ["NEW", "CHANGED", "DELETED"]
    }
  }
}
