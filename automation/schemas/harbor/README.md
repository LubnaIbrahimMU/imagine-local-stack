# Managed Harbor operation schemas

- `harbor-operations.schema.json`: backend validation contract.
- `fetch-images.json`: fetch all authorized Harbor images, optionally filtered
  by `project_name`.
- `delete-image.json`: delete the exact image selected by the user. The backend
  must copy `project_name`, `repository_name`, and `digest` from the
  `fetch-images` result.

The normal GUI edit flow uses the same envelope as MySQL and Redis:
`action_key`, action-specific fields under `service_config`, protected Harbor
admin credentials under the sibling `credentials` object, and the managed VM
under `resources.VM`. The browser must never receive or submit the Harbor admin
password.

The playbook is:

```text
automation/common/managedservices/harbor/harbor-operations.yml
```

Like the MySQL dispatcher, the Harbor dispatcher runs against the managed VM
supplied in the Ansible inventory and calls Harbor locally at
`http://127.0.0.1:8080/api/v2.0`.

## Marketplace edit-action keys

Use the following snake_case values in the admin Edit Item `Key` field. The
field keys listed on the right must be the actual Edit Config `Key` values, not
only the English/Arabic titles.

| Action key | Edit Config keys |
| --- | --- |
| `fetch_harbor` | `project_name` (optional), `page_size` (optional) |
| `fetch_images` | `project_name` (optional), `page_size` (optional) |
| `fetch_users` | `page_size` (optional) |
| `add_project` | `project_name`, `project_public` |
| `add_image` | `project_name`, `project_public`, `local_registry`, `images` |
| `delete_image` | `project_name`, `repository_name`, `digest`, `delete_repository` |
| `delete_project` | `project_name`, `delete_repositories` |
| `add_user` | `project_name`, `user_username`, `user_password`, `user_email`, `user_realname`, `user_comment`, `project_role` |
| `remove_user_from_project` | `project_name`, `user_username` |
| `change_user_role` | `project_name`, `user_username`, `project_role` |
| `reset_user_password` | `user_username`, `new_password` |
| `delete_user` | `user_username` |

Do not add `harbor_username`, `harbor_password`, SSH host, or private-key paths
as browser-editable fields. CloudGate supplies those through `credentials`,
`resources.VM`, Vault, and the Ansible runner.
