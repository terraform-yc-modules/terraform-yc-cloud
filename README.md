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

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name                                                                      | Version  |
| ------------------------------------------------------------------------- | -------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_time"></a> [time](#requirement\_time)                | 0.9.1    |
| <a name="requirement_yandex"></a> [yandex](#requirement\_yandex)          | 0.93     |

## Providers

| Name                                                       | Version |
| ---------------------------------------------------------- | ------- |
| <a name="provider_time"></a> [time](#provider\_time)       | 0.9.1   |
| <a name="provider_yandex"></a> [yandex](#provider\_yandex) | 0.93.0  |

## Modules

No modules.

## Resources

| Name                                                                                                                                                                     | Type        |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------- |
| [time_sleep.this](https://registry.terraform.io/providers/hashicorp/time/0.9.1/docs/resources/sleep)                                                                     | resource    |
| [yandex_billing_cloud_binding.this](https://registry.terraform.io/providers/yandex-cloud/yandex/0.93/docs/resources/billing_cloud_binding)                               | resource    |
| [yandex_organizationmanager_group.this](https://registry.terraform.io/providers/yandex-cloud/yandex/0.93/docs/resources/organizationmanager_group)                       | resource    |
| [yandex_organizationmanager_group_membership.this](https://registry.terraform.io/providers/yandex-cloud/yandex/0.93/docs/resources/organizationmanager_group_membership) | resource    |
| [yandex_resourcemanager_cloud.this](https://registry.terraform.io/providers/yandex-cloud/yandex/0.93/docs/resources/resourcemanager_cloud)                               | resource    |
| [yandex_resourcemanager_cloud_iam_member.this](https://registry.terraform.io/providers/yandex-cloud/yandex/0.93/docs/resources/resourcemanager_cloud_iam_member)         | resource    |
| [yandex_resourcemanager_folder.this](https://registry.terraform.io/providers/yandex-cloud/yandex/0.93/docs/resources/resourcemanager_folder)                             | resource    |
| [yandex_resourcemanager_folder_iam_member.this](https://registry.terraform.io/providers/yandex-cloud/yandex/0.93/docs/resources/resourcemanager_folder_iam_member)       | resource    |
| [yandex_resourcemanager_cloud.this](https://registry.terraform.io/providers/yandex-cloud/yandex/0.93/docs/data-sources/resourcemanager_cloud)                            | data source |

## Inputs

| Name                                                                                                             | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | Type                                                                                                                                                                                                                                                                                                                            | Default | Required |
| ---------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- | :------: |
| <a name="input_billing_account_id"></a> [billing\_account\_id](#input\_billing\_account\_id)                     | (Required) ID of billing account to bind Cloud to.<br>    For more information see https://cloud.yandex.com/en/docs/billing/concepts/billing-account.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | `string`                                                                                                                                                                                                                                                                                                                        | `null`  |    no    |
| <a name="input_cloud"></a> [cloud](#input\_cloud)                                                                | (Required) Configuration of the Cloud.<br>    For more information see https://cloud.yandex.com/en/docs/resource-manager/concepts/resources-hierarchy#cloud.<br><br>    Configuration attributes:<br>      existing\_cloud\_id - (Required, unless using name) Allows to specify an existing Cloud ID. Conflicts with `name`.<br>      name              - (Required, unless using existing\_cloud\_id) The name of the Cloud. Conflicts with `existing_cloud_id`.<br>      description       - (Optional) Description of the Cloud.<br>      labels            - (Optional) A set of key/value label pairs to assign to the Cloud.<br><br>    At least one of `existing_cloud_id`, `name` must be specified.                                                                                 | <pre>object({<br>    existing_cloud_id = optional(string)<br>    name              = optional(string)<br>    description       = optional(string)<br>    labels            = optional(map(string))<br>  })</pre>                                                                                                                | `{}`    |    no    |
| <a name="input_delay_after_cloud_create"></a> [delay\_after\_cloud\_create](#input\_delay\_after\_cloud\_create) | Set a delay before creating folders after cloud creation.<br>    Temporary workaround until the issue of cloud creation by the Terraform provider is resolved.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                | `string`                                                                                                                                                                                                                                                                                                                        | `"60s"` |    no    |
| <a name="input_folders"></a> [folders](#input\_folders)                                                          | (Optional) List of objects of the Cloud Folders.<br>    For more information see https://cloud.yandex.com/en/docs/resource-manager/concepts/resources-hierarchy#folder<br><br>    Configuration attributes:<br>      name        - (Required) The name of the Folder.<br>      description - (Optional) A description of the Folder.<br>      labels      - (Optional) A set of key/value label pairs to assign to the Folder.                                                                                                                                                                                                                                                                                                                                                                | <pre>list(object({<br>    name        = string<br>    description = optional(string)<br>    labels      = optional(map(string))<br>  }))</pre>                                                                                                                                                                                  | `[]`    |    no    |
| <a name="input_groups"></a> [groups](#input\_groups)                                                             | (Optional) List of objects of the Organization Groups.<br>    For more information see https://cloud.yandex.com/en/docs/organization/manage-groups.<br><br>    Configuration attributes:<br>      name         - (Required) The name of the group. Must be unique in each object.<br>      description  - (Optional) A description of the group.<br>      members      - (Optional) List of group members.<br>      cloud\_roles  - (Optional) List of cloud roles for the group.<br>      folder\_roles - (Optional) List of objects with folder name and group roles for this folder.<br><br>    Objects in the `folder_roles` supports the following attributes:<br>      folder\_name - (Required) The name of the folder.<br>      roles       - (Optional) List of roles for the group. | <pre>list(object({<br>    name        = string<br>    description = optional(string)<br>    members     = optional(set(string), [])<br>    cloud_roles = optional(set(string), [])<br>    folder_roles = optional(list(object({<br>      folder_name = string<br>      roles       = set(string)<br>    })), [])<br>  }))</pre> | `[]`    |    no    |
| <a name="input_organization_id"></a> [organization\_id](#input\_organization\_id)                                | (Required) Yandex.Cloud Organization that the Cloud belongs to. If value is omitted, the default provider Organization ID is used.<br>    For more information see https://cloud.yandex.com/en/docs/organization/                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             | `string`                                                                                                                                                                                                                                                                                                                        | `null`  |    no    |

## Outputs

| Name                                                                 | Description                    |
| -------------------------------------------------------------------- | ------------------------------ |
| <a name="output_cloud_id"></a> [cloud\_id](#output\_cloud\_id)       | ID of the Cloud.               |
| <a name="output_cloud_name"></a> [cloud\_name](#output\_cloud\_name) | The name of the Cloud.         |
| <a name="output_folders"></a> [folders](#output\_folders)            | The name of the Сloud folders. |
| <a name="output_groups"></a> [groups](#output\_groups)               | The name of the groups.        |
<!-- END_TF_DOCS -->
