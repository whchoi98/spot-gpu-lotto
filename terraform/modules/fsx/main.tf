# terraform/modules/fsx/main.tf

resource "aws_security_group" "fsx" {
  name_prefix = "${var.name}-fsx-"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-fsx-sg" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "fsx_lustre_inbound" {
  type              = "ingress"
  from_port         = 988
  to_port           = 988
  protocol          = "tcp"
  cidr_blocks       = [var.subnet_cidr]
  security_group_id = aws_security_group.fsx.id
}

resource "aws_security_group_rule" "fsx_lustre_outbound" {
  type              = "egress"
  from_port         = 988
  to_port           = 988
  protocol          = "tcp"
  cidr_blocks       = [var.subnet_cidr]
  security_group_id = aws_security_group.fsx.id
}

resource "aws_fsx_lustre_file_system" "this" {
  storage_capacity   = var.storage_capacity
  subnet_ids         = [var.subnet_id]
  security_group_ids = concat(var.security_group_ids, [aws_security_group.fsx.id])
  deployment_type    = "SCRATCH_2"
  storage_type       = "SSD"

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
