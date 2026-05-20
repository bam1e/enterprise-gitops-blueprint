terraform {
  required_version = ">= 1.5.0"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.0"
    }
  }
}

# ── Variables ─────────────────────────────────────────────────────────────────

variable "argocd_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "6.7.3"
}

variable "argocd_admin_password" {
  description = "ArgoCD admin password (bcrypt hashed)"
  type        = string
  sensitive   = true
  default     = "$2a$10$rRyBsQPe9RPr.WBnQnCF8.dMRXSNflmBFrLnhKpJgGkqG6s9W.XAi"
  # Default decodes to: admin123 — change in production!
}

variable "github_repo_url" {
  description = "GitHub repository URL for ArgoCD to watch"
  type        = string
  default     = "https://github.com/bam1e/enterprise-gitops-blueprint.git"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "local"
}

# ── ArgoCD Namespace ──────────────────────────────────────────────────────────

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
    labels = {
      "managed-by"  = "terraform"
      "environment" = var.environment
      "purpose"     = "gitops"
    }
  }
}

# ── ArgoCD Installation ───────────────────────────────────────────────────────

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  timeout    = 600

  values = [
    file("${path.module}/../cluster-bootstrap/infrastructure/argocd/values.yaml")
  ]

  set_sensitive {
    name  = "configs.secret.argocdServerAdminPassword"
    value = var.argocd_admin_password
  }

  depends_on = [kubernetes_namespace.argocd]
}

# ── Bootstrap Root App-of-Apps ────────────────────────────────────────────────

resource "kubectl_manifest" "root_app" {
  yaml_body = <<-YAML
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: root-app
      namespace: argocd
      finalizers:
        - resources-finalizer.argocd.argoproj.io
    spec:
      project: default
      source:
        repoURL: ${var.github_repo_url}
        targetRevision: HEAD
        path: cluster-bootstrap/apps
      destination:
        server: https://kubernetes.default.svc
        namespace: argocd
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
  YAML

  depends_on = [helm_release.argocd]
}

# ── Outputs ───────────────────────────────────────────────────────────────────

output "argocd_access_command" {
  description = "Command to access ArgoCD UI locally"
  value       = "kubectl port-forward svc/argocd-server -n argocd 8080:443"
}

output "argocd_admin_username" {
  description = "ArgoCD admin username"
  value       = "admin"
}

output "argocd_initial_password_command" {
  description = "Command to get initial admin password"
  value       = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}
