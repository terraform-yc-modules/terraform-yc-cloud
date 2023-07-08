terraform {
  required_version = ">= 1.3.0"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.93"
    }
  }
}

provider "yandex" {}

module "cloud" {
  source = "../../"

  organization_id    = "organization_id_here"
  billing_account_id = "billing_account_id_here"


  cloud_name        = "example-cloud"
  cloud_description = "Example cloud"


  folders = [
    {
      name        = "example-folder-1"
      description = "Example folder 1"
    },
    {
      name        = "example-folder-2"
      description = "Example folder 2"
    }
  ]


  groups = [
    {
      name        = "k8s-admins"
      description = "Kubernetes infrastructure administrators"
      cloud_roles = ["k8s.admin"]
      folder_roles = [
        {
          folder_name = "example-folder-1"
          roles       = ["k8s.tunnelClusters.agent", "container-registry.images.puller"]
        },
        {
          folder_name = "example-folder-2"
          roles       = ["k8s.clusters.agent", "container-registry.images.puller", "vpc.publicAdmin"]
        }
      ]
      members = ["user1_ids_here", "user2_ids_here"]
    },
    {
      name        = "developers"
      description = "Developers"
      cloud_roles = ["k8s.cluster-api.viewer"]
      folder_roles = [
        {
          folder_name = "example-folder-1"
          roles       = ["container-registry.images.pusher", "logging.reader", "monitoring.viewer"]
        }
      ]
      members = ["user3_ids_here", "user4_ids_here"]
    }
  ]
}
