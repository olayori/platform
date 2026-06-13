output "argocd_namespace" {
  value = helm_release.argocd.namespace
}

output "argocd_initial_admin_secret_command" {
  description = "Fetch the initial Argo CD admin password."
  value       = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

output "argocd_port_forward_command" {
  description = "Open the Argo CD UI locally at http://localhost:8080 (server runs insecure)."
  value       = "kubectl -n argocd port-forward svc/argocd-server 8080:80"
}
