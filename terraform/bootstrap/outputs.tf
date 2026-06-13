output "state_bucket_name" {
  description = "Name of the S3 bucket holding all layer state. Use this in backend.hcl."
  value       = aws_s3_bucket.state.id
}

output "region" {
  description = "AWS region."
  value       = var.region
}

output "backend_hcl" {
  description = "Paste this into terraform/backend.hcl for the other layers."
  value       = <<-EOT
    bucket       = "${aws_s3_bucket.state.id}"
    region       = "${var.region}"
    encrypt      = true
    use_lockfile = true
  EOT
}
