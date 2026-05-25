# Security Notes

InfraReaper intentionally keeps the resource catalog small. Adding new temporary resource types should include a matching IAM policy review, default tags, and a destroy path test.

## Recommended Production Settings

- Require API Gateway JWT authorization.
- Deploy into a dedicated AWS account for disposable infrastructure.
- Set `max_ttl_hours` to the smallest practical value.
- Configure `managed_resource_permissions_boundary_arn` before enabling IAM role creation for many users.
- Send Lambda logs to a monitored log group and alert on failed destroy invocations.
- Keep the Terraform layer and provider versions pinned.

## Abuse Resistance

- User input is normalized into slugs before it reaches Terraform.
- TTLs are bounded server-side.
- The Lambda execution role can manage only the resource families represented in `lambdas/resource`.
- IAM role creation is constrained to the `/infrareaper/` path and `ir-*` role names.
- S3 creation is constrained to `ir-*` bucket names.

