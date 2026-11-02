locals {
  cloud_id = var.cloud.existing_cloud_id == null ? yandex_resourcemanager_cloud.this[0].id : var.cloud.existing_cloud_id

  # Creates a list of objects.
  # In each object creates a key/value mapping of the group resource key and cloud role of the group.
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
    for group_key, group in var.groups : [
      for role in group.cloud_roles : {
        group      = group_key
        cloud_role = role
      }
    ]
  ])

  # Creates a list of objects.
  # In each object creates a key/value mapping of the group key, folder key and folder role of the group.
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
    for group_key, group in var.groups : [
      for folder_key, roles in group.folder_roles : [
        for role in roles : {
          folder      = folder_key
          group       = group_key
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

# Conservative activation buffer after billing is bound; not an API readiness probe.
resource "time_sleep" "this" {
  count           = var.cloud.existing_cloud_id == null ? 1 : 0
  create_duration = var.delay_after_cloud_create

  depends_on = [yandex_billing_cloud_binding.this]

  lifecycle {
    replace_triggered_by = [
      yandex_resourcemanager_cloud.this[0].id,
      yandex_billing_cloud_binding.this[0]
    ]
  }
}

resource "yandex_resourcemanager_folder" "this" {
  for_each = var.folders

  cloud_id    = local.cloud_id
  name        = each.value.name
  description = each.value.description
  labels      = each.value.labels

  depends_on = [time_sleep.this]
}

resource "yandex_organizationmanager_group" "this" {
  for_each = var.groups

  name            = each.value.name
  description     = each.value.description
  organization_id = var.organization_id

  lifecycle {
    precondition {
      condition = alltrue([
        for folder_key in keys(each.value.folder_roles) : contains(keys(var.folders), folder_key)
      ])
      error_message = "Group \"${each.key}\" references unknown folder keys: ${join(", ", setsubtract(toset(keys(each.value.folder_roles)), toset(keys(var.folders))))}. Use keys from the folders map."
    }
  }
}

resource "yandex_resourcemanager_cloud_iam_member" "this" {
  for_each = {
    for item in local.cloud_iam_bindings : "group:${item.group}:role:${item.cloud_role}" => item
  }

  cloud_id = local.cloud_id
  role     = each.value.cloud_role
  member   = "group:${yandex_organizationmanager_group.this[each.value.group].id}"

  depends_on = [time_sleep.this]
}

resource "yandex_resourcemanager_folder_iam_member" "this" {
  # The group precondition reports unknown keys; filtering avoids invalid indexing.
  for_each = {
    for item in local.folder_iam_bindings : "group:${item.group}:folder:${item.folder}:role:${item.folder_role}" => item
    if contains(keys(var.folders), item.folder)
  }

  folder_id = yandex_resourcemanager_folder.this[each.value.folder].id
  role      = each.value.folder_role
  member    = "group:${yandex_organizationmanager_group.this[each.value.group].id}"
}

resource "yandex_organizationmanager_group_membership" "this" {
  for_each = {
    for group_key, group in var.groups : group_key => group if group.manage_members
  }

  group_id = yandex_organizationmanager_group.this[each.key].id
  members  = each.value.members
}
