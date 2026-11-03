# Cloud bootstrap Terraform module for Yandex.Cloud
## prerequisites
Use Yandex-id account with roles:
- `billing.accounts.editor` or higher to attach cloud to billing account 
- `resource-manager.admin` on organization level to create cloud and folders
- `organization-manager.admin` to create groups

## Features

- Create a cloud or use an existing one
- Сreate cloud folders
- Сreate organization groups
- Add users to organization groups
- Assign cloud permissions to a group
- Assign folders permissions to a group

## How to configure Terraform to use a module

- Install [YC CLI](https://cloud.yandex.com/docs/cli/quickstart)
- Add environment variables for terraform auth in Yandex.Cloud

```bash
export YC_TOKEN=$(yc iam create-token)
```

### Examples

See [examples section](./examples/)

### Map inputs and stable resource keys

`folders` and `groups` are maps of objects. Each map key identifies a resource in
Terraform state independently of its cloud-visible `name`. Keys must be
nonblank and must not contain `:`. Keep keys unchanged when renaming resources.

```hcl
folders = {
  dev = {
    name = "development"
  }
}

groups = {
  admins = {
    name        = "k8s-admins"
    cloud_roles = ["k8s.admin"]
    folder_roles = {
      dev = ["k8s.cluster-api.cluster-admin"]
    }
  }
}
```

`folder_roles` has type `map(set(string))`: each key must exist in the `folders`
map, and its value contains the roles assigned to that group on the folder.
References always use map keys, so renaming a folder does not require changes to
role assignments. Repeated roles are deduplicated by the set type.

Omitting `folder_roles` defaults to `{}`. An empty role set (`[]`) assigns no
roles, but its folder key must still exist. Role sets must not be `null`.

### Group membership management

Group creation and IAM assignments are independent of membership management.
For each group, explicitly choose whether this module manages member IDs:

```hcl
groups = {
  external = {
    name = "externally-managed-group"
    # manage_members defaults to false; omit members.
  }
  developers = {
    name           = "developers"
    manage_members = true
    members        = ["user_id_here"]
  }
  empty = {
    name           = "empty-managed-group"
    manage_members = true
    members        = []
  }
}
```

- `manage_members = false` (default): no membership resource is declared.
  Omit `members` or set it to `null`.
- `manage_members = true`: `members` is required. It may be empty or computed
  during apply. The membership resource remains declared even when `members = []`.

`manage_members` and group map keys must be known during plan. Member IDs and the
size of the managed set may remain unknown until apply.

The provider manages the memberships it tracks, rather than enforcing the entire
group's membership. Members added outside this resource remain unmanaged.
Changing a managed member set to `[]` removes the previously tracked memberships
while retaining the membership resource. It does not remove unrelated external
members. Removing the membership resource (including by setting `manage_members`
to `false`) revokes the member IDs tracked by that resource before removing it
from state. This behavior was checked in the [provider v0.243.0 implementation](https://github.com/yandex-cloud/terraform-provider-yandex/blob/v0.243.0/yandex/resource_yandex_organizationmanager_group_membership.go).

To stop managing an existing membership **without revoking its members**, change
the group to `manage_members = false`, omit `members`, and forget only the
membership resource from state before applying. For example, for a module call
named `cloud` and a group key `developers`:

```bash
terraform state rm 'module.cloud.yandex_organizationmanager_group_membership.this["developers"]'
terraform plan
```

Verify that the plan does not destroy the membership or recreate it. Do not
remove the group resource from state. This procedure also works with the
module's minimum supported Terraform version, 1.3.

Keys are used consistently for folders, groups, cloud and folder IAM assignments,
and group memberships. The `folders` and `groups` outputs retain their list
shape and fields (`id`, `name`), but are now **sorted lexicographically by map
key**. Changing declaration order does not affect these outputs. Migrating from
a list may reorder an output list once; this does not replace cloud resources.

### Migrating existing list inputs

This version changes the input types of `folders` and `groups` from
`list(object(...))` to `map(object(...))`. Both lists must be converted, including
empty lists (`[]` becomes `{}`).

For each list element, use its existing `name` as the new map key. Preserve all
other properties, roles, and members. For example:

```hcl
# Before
folders = [
  {
    name = "example-folder-1"
  }
]

# After
folders = {
  "example-folder-1" = {
    name = "example-folder-1"
  }
}
```

Convert `groups` in the same way. Also convert each group's `folder_roles` from
a list of folder-role objects to a map of folder keys and role sets:

```hcl
# Before
folder_roles = [
  {
    folder_name = "example-folder-1"
    roles       = ["k8s.cluster-api.cluster-admin"]
  }
]

# After
folder_roles = {
  "example-folder-1" = ["k8s.cluster-api.cluster-admin"]
}
```

Each assignment key must match a key in the new `folders` map. Empty
`folder_roles` lists (`[]`) become empty maps (`{}`).

For groups whose members were managed, add `manage_members = true` and preserve
the existing `members` values. The membership resource address stays unchanged.
For groups that previously omitted `members` or used `members = []`, omit
`members` and leave `manage_members = false` to preserve the absence of a
membership resource. Use `manage_members = true` with `members = []` only when an
empty managed set is intended. A supplied member set without the flag is rejected
so that migration cannot silently revoke managed memberships.

Verify the chosen folder and group map keys against
`terraform state list`, especially when a resource has already been renamed.
Keeping these keys preserves the existing resource addresses: no `moved` blocks
or state manipulation are needed merely to convert the input type. The plan
should contain no cloud resource changes when the configuration matches the
existing infrastructure; output lists may change order as described above.

After migration, change only `name` to rename a resource. Keep its map key and
the keys in `folder_roles` fixed.

Choosing a different map key for an existing resource changes its Terraform
address. Before applying, add root-level `moved` blocks for **every affected
address**: the folder or group, related IAM assignments, and group memberships.
For example, changing only a folder key from `example-folder-1` to `dev` requires
the folder move and a move for each of its folder IAM assignments:

```hcl
moved {
  from = module.cloud.yandex_resourcemanager_folder.this["example-folder-1"]
  to   = module.cloud.yandex_resourcemanager_folder.this["dev"]
}

moved {
  from = module.cloud.yandex_resourcemanager_folder_iam_member.this["group:k8s-admins:folder:example-folder-1:role:k8s.cluster-api.cluster-admin"]
  to   = module.cloud.yandex_resourcemanager_folder_iam_member.this["group:k8s-admins:folder:dev:role:k8s.cluster-api.cluster-admin"]
}
```

Repeat the IAM move for all other assignments to this folder. When changing a
group key, also move its group membership, cloud IAM, and folder IAM addresses.
Move addresses without renaming resources first; verify the plan before applying.

### New-cloud activation buffer

For a new cloud, the module orders operations as follows:

```text
cloud -> billing binding -> activation buffer -> folders and cloud IAM members
                                             -> consumers of output.cloud_id
```

Organization groups and their memberships can be created independently. When
`cloud.existing_cloud_id` is set, the module neither binds billing nor creates a
sleep resource; the existing cloud must already be usable.

`delay_after_cloud_create` defaults to `"180s"`. The buffer starts **after
billing binding completes**. Set it to `"0s"` to skip the buffer
while retaining the dependency ordering. Replacing a cloud or updating/replacing
its billing binding recreates the wait. Renaming the cloud does not. Changing
only the duration updates the sleep resource and does not repeat a completed
wait. The wait resource address remains unchanged, and adding these lifecycle
rules does not by itself replace an existing completed wait.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.9.1 |
| <a name="requirement_yandex"></a> [yandex](#requirement\_yandex) | >= 0.87.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_time"></a> [time](#provider\_time) | 0.14.2 |
| <a name="provider_yandex"></a> [yandex](#provider\_yandex) | 0.243.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [time_sleep.this](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [yandex_billing_cloud_binding.this](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/billing_cloud_binding) | resource |
| [yandex_organizationmanager_group.this](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/organizationmanager_group) | resource |
| [yandex_organizationmanager_group_membership.this](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/organizationmanager_group_membership) | resource |
| [yandex_resourcemanager_cloud.this](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/resourcemanager_cloud) | resource |
| [yandex_resourcemanager_cloud_iam_member.this](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/resourcemanager_cloud_iam_member) | resource |
| [yandex_resourcemanager_folder.this](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/resourcemanager_folder) | resource |
| [yandex_resourcemanager_folder_iam_member.this](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/resourcemanager_folder_iam_member) | resource |
| [yandex_resourcemanager_cloud.this](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/data-sources/resourcemanager_cloud) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_billing_account_id"></a> [billing\_account\_id](#input\_billing\_account\_id) | (Required) ID of billing account to bind Cloud to.<br/>    For more information see https://cloud.yandex.com/en/docs/billing/concepts/billing-account. | `string` | `null` | no |
| <a name="input_cloud"></a> [cloud](#input\_cloud) | (Required) Configuration of the Cloud.<br/>    For more information see https://cloud.yandex.com/en/docs/resource-manager/concepts/resources-hierarchy#cloud.<br/><br/>    Configuration attributes:<br/>      existing\_cloud\_id - (Required, unless using name) Allows to specify an existing Cloud ID. Conflicts with `name`.<br/>      name              - (Required, unless using existing\_cloud\_id) The name of the Cloud. Conflicts with `existing_cloud_id`.<br/>      description       - (Optional) Description of the Cloud.<br/>      labels            - (Optional) A set of key/value label pairs to assign to the Cloud.<br/><br/>    At least one of `existing_cloud_id`, `name` must be specified. | <pre>object({<br/>    existing_cloud_id = optional(string)<br/>    name              = optional(string)<br/>    description       = optional(string)<br/>    labels            = optional(map(string))<br/>  })</pre> | `{}` | no |
| <a name="input_delay_after_cloud_create"></a> [delay\_after\_cloud\_create](#input\_delay\_after\_cloud\_create) | Activation buffer after binding a new cloud to billing, before folders, cloud IAM assignments and cloud\_id consumers.<br/>    Defaults to 180s; use 0s to disable the buffer. Existing clouds are not delayed. This is not an API readiness probe. | `string` | `"180s"` | no |
| <a name="input_folders"></a> [folders](#input\_folders) | (Optional) Map of Cloud Folders, indexed by stable Terraform resource keys.<br/>    For more information see https://cloud.yandex.com/en/docs/resource-manager/concepts/resources-hierarchy#folder<br/><br/>    Configuration attributes:<br/>      name        - (Required) The name of the Folder.<br/>      description - (Optional) A description of the Folder.<br/>      labels      - (Optional) A set of key/value label pairs to assign to the Folder. | <pre>map(object({<br/>    name        = string<br/>    description = optional(string)<br/>    labels      = optional(map(string))<br/>  }))</pre> | `{}` | no |
| <a name="input_groups"></a> [groups](#input\_groups) | (Optional) Map of Organization Groups, indexed by stable Terraform resource keys.<br/>    For more information see https://cloud.yandex.com/en/docs/organization/manage-groups.<br/><br/>    Configuration attributes:<br/>      name           - (Required) The name of the group. Must be unique in each object.<br/>      description    - (Optional) A description of the group.<br/>      manage\_members - (Optional) Whether to manage declared group memberships. Defaults to false and must be known at plan time.<br/>      members        - (Optional) Set of managed member IDs. Required when manage\_members is true; use [] for an empty managed set. Omit otherwise.<br/>      cloud\_roles    - (Optional) List of cloud roles for the group.<br/>      folder\_roles   - (Optional) Map of folder keys to sets of roles for the group. Each key must exist in folders. | <pre>map(object({<br/>    name           = string<br/>    description    = optional(string)<br/>    manage_members = optional(bool, false)<br/>    members        = optional(set(string))<br/>    cloud_roles    = optional(set(string), [])<br/>    folder_roles   = optional(map(set(string)), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_organization_id"></a> [organization\_id](#input\_organization\_id) | (Required) Yandex.Cloud Organization that the Cloud belongs to. If value is omitted, the default provider Organization ID is used.<br/>    For more information see https://cloud.yandex.com/en/docs/organization/ | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_cloud_id"></a> [cloud\_id](#output\_cloud\_id) | ID of the Cloud. |
| <a name="output_cloud_name"></a> [cloud\_name](#output\_cloud\_name) | The name of the Cloud. |
| <a name="output_folders"></a> [folders](#output\_folders) | Folder IDs and names, sorted by map key. |
| <a name="output_groups"></a> [groups](#output\_groups) | Group IDs and names, sorted by map key. |
<!-- END_TF_DOCS -->
