# security-compliance/opa/terraform-security-constraints.yaml
# OPA Rego policies for Terraform IaC scanning
# Used by Conftest in CI pipelines to block insecure configurations
# These rules run on every PR touching Terraform files

package terraform.security

import future.keywords.if
import future.keywords.in

# ── Rule 1: Block open security groups ───────────────────────────────────────
deny[msg] if {
  resource := input.resource.aws_security_group[name]
  ingress := resource.ingress[_]
  ingress.cidr_blocks[_] == "0.0.0.0/0"
  ingress.from_port == 0
  ingress.to_port == 0

  msg := sprintf(
    "CRITICAL: Security group '%s' allows ALL traffic from 0.0.0.0/0 on all ports. Restrict ingress rules.",
    [name]
  )
}

# ── Rule 2: Block unencrypted S3 buckets ─────────────────────────────────────
deny[msg] if {
  resource := input.resource.aws_s3_bucket[name]
  not resource.server_side_encryption_configuration

  msg := sprintf(
    "CRITICAL: S3 bucket '%s' has no server-side encryption. Add server_side_encryption_configuration.",
    [name]
  )
}

# ── Rule 3: Block public S3 buckets ──────────────────────────────────────────
deny[msg] if {
  resource := input.resource.aws_s3_bucket[name]
  resource.acl == "public-read"

  msg := sprintf(
    "CRITICAL: S3 bucket '%s' has public-read ACL. Use private ACL and bucket policies instead.",
    [name]
  )
}

# ── Rule 4: Require tags on all resources ────────────────────────────────────
required_tags := {"Environment", "ManagedBy", "Owner"}

warn[msg] if {
  resource := input.resource.aws_instance[name]
  missing := required_tags - {tag | resource.tags[tag]}
  count(missing) > 0

  msg := sprintf(
    "WARNING: EC2 instance '%s' is missing required tags: %v",
    [name, missing]
  )
}

# ── Rule 5: Block unencrypted RDS instances ───────────────────────────────────
deny[msg] if {
  resource := input.resource.aws_db_instance[name]
  not resource.storage_encrypted

  msg := sprintf(
    "CRITICAL: RDS instance '%s' has storage_encrypted=false. Enable encryption at rest.",
    [name]
  )
}

# ── Rule 6: Block RDS publicly accessible ─────────────────────────────────────
deny[msg] if {
  resource := input.resource.aws_db_instance[name]
  resource.publicly_accessible == true

  msg := sprintf(
    "CRITICAL: RDS instance '%s' is publicly accessible. Set publicly_accessible=false.",
    [name]
  )
}

# ── Rule 7: Require HTTPS on ALB listeners ────────────────────────────────────
deny[msg] if {
  resource := input.resource.aws_lb_listener[name]
  resource.protocol == "HTTP"
  not resource.default_action.redirect

  msg := sprintf(
    "WARNING: ALB listener '%s' uses HTTP without redirect. Use HTTPS or add HTTP->HTTPS redirect.",
    [name]
  )
}

# ── Rule 8: Block IAM wildcard actions ────────────────────────────────────────
deny[msg] if {
  resource := input.resource.aws_iam_policy[name]
  statement := resource.policy.Statement[_]
  statement.Effect == "Allow"
  statement.Action == "*"

  msg := sprintf(
    "CRITICAL: IAM policy '%s' uses wildcard Action '*'. Follow least-privilege — specify exact actions.",
    [name]
  )
}
