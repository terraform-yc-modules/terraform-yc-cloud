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
      name        = "example-group-1"
      description = "Example group 1"
      cloud_roles = ["kms.admin", "storage.admin"]
      folder_roles = [
        {
          folder_name = "example-folder-1"
          roles       = ["k8s.admin", "alb.editor"]
        },
        {
          folder_name = "example-folder-2"
          roles       = ["k8s.admin", "alb.editor"]
        }
      ]
      members = ["user1_ids_here", "user2_ids_here"]
    },
    {
      name        = "example-group-2"
      description = "Example group 2"
      cloud_roles = ["storage.admin", "vpc.admin"]
      folder_roles = [
        {
          folder_name = "example-folder-2"
          roles       = ["compute.viewer", "container-registry.admin"]
        }
      ]
      members = ["user2_ids_here", "user3_ids_here"]
    }
  ]
}
