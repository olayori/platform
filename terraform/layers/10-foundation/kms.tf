# ---------------------------------------------------------------------------
# KMS key for EKS secret envelope encryption
# ---------------------------------------------------------------------------
# Created in the foundation layer so the key outlives any cluster rebuild and
# the compute layer can simply reference it via remote state.
# ---------------------------------------------------------------------------

resource "aws_kms_key" "eks" {
  description             = "${local.name} EKS secrets envelope encryption"
  deletion_window_in_days = 14
  enable_key_rotation     = true
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${local.name}-eks"
  target_key_id = aws_kms_key.eks.key_id
}
