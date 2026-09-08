# Application workloads: cert-manager, PostgreSQL, Fedora, Solr, namespaces, kubectl manifests.
# All file() paths are under ops/provision/k8s/ (or k8s/ relative to this root).

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  version          = "1.17.1"
  repository       = "https://charts.jetstack.io"
  chart            = "jetstack/cert-manager"

  set {
    name  = "installCRDs"
    value = "true"
  }

  lifecycle {
    ignore_changes = [create_namespace, repository, set, values]
  }
}

resource "kubectl_manifest" "cloudflare_api_token_secret" {
  depends_on = [helm_release.cert_manager]
  yaml_body  = file("${path.module}/k8s/cloudflare-api-token-secret.yaml")
}

resource "kubectl_manifest" "prod_issuer" {
  depends_on = [helm_release.cert_manager]
  yaml_body  = file("${path.module}/k8s/prod_issuer.yaml")
}

resource "kubectl_manifest" "prod_issuer_dns" {
  depends_on = [helm_release.cert_manager]
  yaml_body  = file("${path.module}/k8s/prod-issuer-dns-values.yaml")
}

# postgresql (default ns) and postgresql-17 (default ns) are Helm-only — see README "Helm-only releases".

resource "helm_release" "postgresql_fcrepo" {
  name             = "postgresql"
  namespace        = "fcrepo"
  create_namespace = true
  chart            = "oci://registry-1.docker.io/bitnamicharts/postgresql"
  values           = [file("${path.module}/k8s/postgresql-values.yaml")]
  timeout          = 600

  lifecycle {
    # values not ignored so Terraform can push metrics.enabled and other k8s/postgresql-values.yaml changes
    ignore_changes = [create_namespace, repository, set]
  }
}

resource "helm_release" "postgresql_fcrepo_staging" {
  name             = "postgresql"
  namespace        = "fcrepo-staging"
  create_namespace = true
  chart            = "oci://registry-1.docker.io/bitnamicharts/postgresql"
  values           = [file("${path.module}/k8s/postgresql-values.yaml")]
  timeout          = 600

  lifecycle {
    # values not ignored so Terraform can push metrics.enabled and other k8s/postgresql-values.yaml changes
    ignore_changes = [create_namespace, repository, set]
  }
}

resource "helm_release" "fcrepos3" {
  depends_on       = [helm_release.postgresql_fcrepo]
  name             = "fcrepo"
  namespace        = "fcrepo"
  create_namespace = true
  repository       = "https://samvera-labs.github.io/fcrepo-charts"
  chart            = "fcrepo"
  values           = [file("${path.module}/k8s/fcrepos3-values.yaml")]

  lifecycle {
    ignore_changes = [create_namespace, repository, set, values]
  }
}

resource "helm_release" "fcrepos3_staging" {
  depends_on       = [helm_release.postgresql_fcrepo_staging]
  name             = "fcrepo-staging"
  namespace        = "fcrepo-staging"
  create_namespace = true
  repository       = "https://samvera-labs.github.io/fcrepo-charts"
  chart            = "fcrepo"
  values           = [file("${path.module}/k8s/fcrepos3-values.yaml")]

  lifecycle {
    ignore_changes = [create_namespace, repository, set, values]
  }
}

# solr (default ns) is Helm-only — see README "Helm-only releases".

resource "kubernetes_namespace" "ethos_knapsack_staging" {
  metadata {
    name = "ethos-knapsack-staging"
    annotations = {
      "field.cattle.io/projectId"                 = "c-z9r2f:p-gzjr4"
      "lifecycle.cattle.io/create.namespace-auth" = "true"
    }
    labels = {
      "field.cattle.io/projectId" = "p-gzjr4"
    }
  }

  lifecycle {
    ignore_changes = [metadata[0].annotations, metadata[0].labels]
  }
}

resource "kubernetes_namespace" "ethos_knapsack_production" {
  metadata {
    name = "ethos-knapsack-production"
    annotations = {
      "field.cattle.io/projectId"                 = "c-z9r2f:p-gzjr4"
      "lifecycle.cattle.io/create.namespace-auth" = "true"
    }
    labels = {
      "field.cattle.io/projectId" = "p-gzjr4"
    }
  }

  lifecycle {
    ignore_changes = [metadata[0].annotations, metadata[0].labels]
  }
}

resource "kubectl_manifest" "github_registry_secret_staging" {
  depends_on          = [helm_release.cert_manager]
  yaml_body           = templatefile("${path.module}/k8s/github-registry-secret-values.yaml", {})
  override_namespace  = "ethos-knapsack-staging"
}

resource "kubectl_manifest" "github_registry_secret_production" {
  depends_on          = [helm_release.cert_manager]
  yaml_body           = templatefile("${path.module}/k8s/github-registry-secret-values.yaml", {})
  override_namespace  = "ethos-knapsack-production"
}
