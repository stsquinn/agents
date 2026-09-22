# shared

The state bucket and the IAM roles. Applied once, by hand, before any other
stack can init.

From the repo root:

```bash
export AWS_PROFILE=__AWS_PROFILE__

just bootstrap
# uncomment the backend block in versions.tf
just migrate-state

just output shared   # -> AWS_PLAN_ROLE_ARN, AWS_APPLY_ROLE_ARN repo variables
```

Starts on local state because this stack creates the bucket it later stores
state in. Do the apply and the migrate in one sitting — until the second step
runs, state sits on the operator's laptop.

The bucket carries `prevent_destroy`.
