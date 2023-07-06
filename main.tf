locals {
  cloud_id = var.cloud.existing_cloud_id == null ? yandex_resourcemanager_cloud.this[0].id : var.cloud.existing_cloud_id

  # Creates a list of objects.
  # In each object creates a key/value mapping of the group name and cloud role of the group.
  # Result example:
  #   cloud_iam_bindings = [
  #     {
  #       group      = "example-group-1"
  #       cloud_role = "kms.admin"
  #     },
  #     {
  #       group      = "example-group-1"
  #       cloud_role = "storage.admin"
  #     },
  #     {
  #       group      = "example-group-2"
  #       cloud_role = "storage.admin"
  #     },
  #     {
  #       group      = "example-group-2"
  #       cloud_role = "vpc.admin"
  #     }
  #   ]
  cloud_iam_bindings = flatten([
    for group in var.groups : [
      for role in group.cloud_roles : {
        group      = group.name
        cloud_role = role
      }
    ]
  ])

  # Creates a list of objects.
  # In each object creates a key/value mapping of the group name, folder name and folder role of the group.
  # Result example:
  #   folder_iam_bindings = [
  #     {
  #       group       = "example-group-1"
  #       folder      = "example-folder-1"
  #       folder_role = "alb.editor"
  #     },
  #     {
  #       group       = "example-group-1"
  #       folder      = "example-folder-1"
  #       folder_role = "k8s.admin"
  #     },
  #     {
  #       group       = "example-group-1"
  #       folder      = "example-folder-2"
  #       folder_role = "compute.viewer"
  #     },
  #     {
  #       group       = "example-group-1"
  #       folder      = "example-folder-2"
  #       folder_role = "container-registry.admin"
  #     }
  #   ]
  folder_iam_bindings = flatten([
    for group in var.groups : [
      for folder in group.folder_roles : [
        for role in folder.roles : {
          folder      = folder.folder_name
          group       = group.name
          folder_role = role
        }
      ]
    ]
  ])
}

data "yandex_resourcemanager_cloud" "this" {
  count    = var.cloud.existing_cloud_id != null ? 1 : 0
  cloud_id = var.cloud.existing_cloud_id
}

resource "yandex_resourcemanager_cloud" "this" {
  count           = var.cloud.existing_cloud_id == null ? 1 : 0
  name            = var.cloud.name
  description     = var.cloud.description
  organization_id = var.organization_id
  labels          = var.cloud.labels
}

resource "yandex_billing_cloud_binding" "this" {
  count              = var.cloud.existing_cloud_id == null ? 1 : 0
  billing_account_id = var.billing_account_id
  cloud_id           = yandex_resourcemanager_cloud.this[0].id
}

# Temporary workaround until the issue of cloud creation by the Terraform provider is resolved.
resource "time_sleep" "this" {
  count           = var.cloud.existing_cloud_id == null ? 1 : 0
  create_duration = var.delay_after_cloud_create

  depends_on = [yandex_resourcemanager_cloud.this]
}

resource "yandex_resourcemanager_folder" "this" {
  for_each = {
    for folder in var.folders : folder.name => folder
  }

  cloud_id    = local.cloud_id
  name        = each.value.name
  description = each.value.description
  labels      = each.value.labels

  depends_on = [
    yandex_resourcemanager_cloud.this,
    yandex_billing_cloud_binding.this,
    time_sleep.this
  ]
}

resource "yandex_organizationmanager_group" "this" {
  for_each = {
    for group in var.groups : group.name => group
  }

  name            = each.value.name
  description     = each.value.description
  organization_id = var.organization_id
}

resource "yandex_resourcemanager_cloud_iam_member" "this" {
  for_each = {
    for item in local.cloud_iam_bindings : "group:${item.group}:role:${item.cloud_role}" => item
  }

  cloud_id = local.cloud_id
  role     = each.value.cloud_role
  member   = "group:${yandex_organizationmanager_group.this[each.value.group].id}"
}

resource "yandex_resourcemanager_folder_iam_member" "this" {
  for_each = {
    for item in local.folder_iam_bindings : "group:${item.group}:folder:${item.folder}:role:${item.folder_role}" => item
  }

  folder_id = yandex_resourcemanager_folder.this[each.value.folder].id
  role      = each.value.folder_role
  member    = "group:${yandex_organizationmanager_group.this[each.value.group].id}"

  lifecycle {
    precondition {
      condition     = contains([for folder in var.folders : folder.name], each.value.folder)
      error_message = <<EOF
        Cannot assign folder role "${each.value.folder_role}" for group "${each.value.group}".
        Folder "${each.value.folder}" not found in "folders" variable.
      EOF
    }
  }
}

resource "yandex_organizationmanager_group_membership" "this" {
  for_each = {
    for group in var.groups : group.name => group.members if length(group.members) != 0
  }

  group_id = yandex_organizationmanager_group.this[each.key].id
  members  = each.value
}
