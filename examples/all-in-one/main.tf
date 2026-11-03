terraform {
  required_version = ">= 1.3.0"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "> 0.9"
    }
  }
}

provider "yandex" {}

module "cloud" {
  source = "../../"

  organization_id    = "organization_id_here"
  billing_account_id = "billing_account_id_here"

  cloud = {
    name        = "example-cloud"
    description = "Example cloud"
  }


  folders = {
    "example-folder-1" = {
      name        = "example-folder-1"
      description = "Example folder 1 (i.e. development)"
    }
    "example-folder-2" = {
      name        = "example-folder-prod"
      description = "Example folder 2 (i.e. production)"
    }
  }


  groups = {
    "k8s-admins" = {
      name        = "k8s-admins"
      description = "Kubernetes infrastructure administrators"
      cloud_roles = ["k8s.admin"]
      folder_roles = {
        "example-folder-1" = ["k8s.cluster-api.cluster-admin", "container-registry.images.puller"]
        "example-folder-2" = ["k8s.cluster-api.cluster-admin", "container-registry.images.puller", "vpc.publicAdmin"]
      }
      manage_members = true
      members        = ["user1_ids_here", "user2_ids_here"]
    }
    "developers" = {
      name        = "developers"
      description = "Developers"
      cloud_roles = ["k8s.viewer"]
      folder_roles = {
        "example-folder-1" = [
          "k8s.cluster-api.editor",
          "container-registry.images.pusher",
          "monium.logs.reader",
          "monium.metrics.reader",
          "monium.dashboards.viewer",
        ]
      }
      manage_members = true
      members        = ["user3_ids_here", "user4_ids_here"]
    }
  }
}
