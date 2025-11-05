terraform {
  backend "pg" {}
  required_version = ">= 0.13"

  required_providers {
    rancher2 = {
      source = "rancher/rancher2"
      version = "8.1"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

variable "region" {
  default     = "eu-west-1"
  description = "AWS region"
}

provider "aws" {
  region = var.region
}

provider "helm" {
  kubernetes = {
    config_path = "kube_config.yml"
  }
}

provider "kubectl" {
  config_path = "kube_config.yml"
}

provider "kubernetes" {
  config_path = "kube_config.yml"
}

data "local_file" "efs_name" {
  filename = "efs_name"
}

data "aws_caller_identity" "current" {}

data "aws_eks_cluster" "cluster" {
  name = "r2-bl-ethos"
}

resource "aws_iam_policy" "aws_load_balancer_controller" {
  name        = "AWSLoadBalancerControllerIAMPolicy"
  description = "IAM policy for AWS Load Balancer Controller"
  policy      = file("aws-load-balancer-controller-policy.json")
}

resource "aws_iam_role" "aws_load_balancer_controller" {
  name = "AWSLoadBalancerControllerRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}"
        }
        Condition = {
          StringEquals = {
            "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
            "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:aud": "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
  role       = aws_iam_role.aws_load_balancer_controller.name
}

resource "kubernetes_service_account" "aws_load_balancer_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.aws_load_balancer_controller.arn
    }
  }
}

resource "helm_release" "aws-load-balancer" {
  chart   = "aws-load-balancer-controller"
  name    = "aws-load-balancer-controller"
  namespace = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  depends_on = [kubernetes_service_account.aws_load_balancer_controller]
  set = [
    { name  = "clusterName", value = "r2-bl-ethos"},
    { name = "serviceAccount.create", value = "false" },
    { name = "serviceAccount.name", value = "aws-load-balancer-controller" },
    { name = "region", value = "eu-west-1" },
    { name = "vpcId", value = "vpc-0e75da99cc686b282" }
  ]
}

resource "helm_release" "ingress-nginx" {
  name = "ingress-nginx"
  namespace = "ingress-nginx"
  create_namespace = true
  version = "4.5.2"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart = "ingress-nginx"
  depends_on = [helm_release.aws-load-balancer]
  values = [
    file("k8s/ingress-nginx-values.yaml")
  ]
}

resource "kubernetes_storage_class" "storage_class" {
  storage_provisioner = "efs.csi.aws.com"

  parameters = {
    directoryPerms   = "700"
    fileSystemId     = trimspace(data.local_file.efs_name.content)
    provisioningMode = "efs-ap"
  }

  metadata {
    name = "efs-sc"
  }
}

resource "helm_release" "cert_manager" {
  name = "cert-manager"
  namespace = "cert-manager"
  create_namespace = true
  version = "1.17.1"
  repository = "https://charts.jetstack.io"
  chart = "cert-manager"

  set = [{
    name  = "installCRDs"
    value = "true"
  }]
}

resource "kubectl_manifest" "cloudflare-api-token-secret" {
  depends_on = [helm_release.cert_manager]
  yaml_body  = file("./k8s/cloudflare-api-token-secret.yaml")
}

resource "kubectl_manifest" "prod_issuer" {
  depends_on = [helm_release.cert_manager]
  yaml_body = file("./k8s/prod_issuer.yaml")
}

resource "kubectl_manifest" "prod_issuer_dns" {
  depends_on = [helm_release.cert_manager]
  yaml_body = file("./k8s/prod-issuer-dns-values.yaml")
}

resource "helm_release" "postgresql" {
  name             = "postgresql"
  namespace        = "default"
  create_namespace = true

  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "postgresql"
  # Pin to the exact version you were using:
  # version  = var.bitnami_postgresql_version
  values    = [file("k8s/postgresql-values.yaml")]
}

resource "helm_release" "postgresql-fcrepo" {
  name             = "postgresql"
  namespace        = "fcrepo"
  create_namespace = true

  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "postgresql"
  # version  = var.bitnami_postgresql_version
  values    = [file("k8s/postgresql-values.yaml")]
}

resource "helm_release" "postgresql-fcrepo-staging" {
  name             = "postgresql"
  namespace        = "fcrepo-staging"
  create_namespace = true

  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "postgresql"
  # version  = var.bitnami_postgresql_version
  values    = [file("k8s/postgresql-values.yaml")]
}

resource "helm_release" "fcrepos3" {
  depends_on = [helm_release.postgresql-fcrepo]

  name = "fcrepo"
  namespace = "fcrepo"
  create_namespace = true
  repository = "https://samvera-labs.github.io/fcrepo-charts"
  chart = "fcrepo"
  values = [
    file("k8s/fcrepos3-values.yaml")
  ]
}

resource "helm_release" "fcrepos3-staging" {
  depends_on = [helm_release.postgresql-fcrepo-staging]

  name = "fcrepo-staging"
  namespace = "fcrepo-staging"
  create_namespace = true
  repository = "https://samvera-labs.github.io/fcrepo-charts"
  chart = "fcrepo"
  values = [
    file("k8s/fcrepos3-values.yaml")
  ]
}

resource "helm_release" "solr" {
  name             = "solr"
  namespace        = "default"
  create_namespace = true

  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "solr"
  # version  = var.bitnami_solr_version
  values    = [file("k8s/solr-values.yaml")]
}

resource "kubernetes_namespace" "ethos-knapsack-staging" {
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
}

resource "kubernetes_namespace" "ethos-knapsack-production" {
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
}

resource "kubectl_manifest" "github-registry-secret-staging" {
  depends_on = [helm_release.cert_manager]
  yaml_body = templatefile("k8s/github-registry-secret-values.yaml", {})
  override_namespace = "ethos-knapsack-staging"
}

resource "kubectl_manifest" "github-registry-secret-production" {
  depends_on = [helm_release.cert_manager]
  yaml_body = templatefile("k8s/github-registry-secret-values.yaml", {})
  override_namespace = "ethos-knapsack-production"
}