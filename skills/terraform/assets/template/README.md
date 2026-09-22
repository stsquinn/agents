# __GITHUB_REPO__

One AWS account (`__ACCOUNT_ID__`, `__REGION__`), two environments: **stg** and **prod**.

```
shared/         state bucket + GitHub OIDC + the plan/apply/readonly roles
envs/stg/       root module, state key envs/stg/terraform.tfstate
envs/prod/      root module, state key envs/prod/terraform.tfstate
modules/        network · ec2-app-host · rds-mysql · s3-bucket · security-group
scripts/        aws-inventory.sh -- read-only sweep that scaffolds import blocks
justfile        every command, shared with CI
```

One bucket holds all state, separated by key, locked natively (`use_lockfile`).
Environments are directories, not workspaces.

## Bootstrap

```mermaid
graph LR
  A["1 · shared/<br/>local state"] -->|creates bucket| B[("state bucket")]
  A -->|"2 · uncomment backend<br/>init -migrate-state"| B
  A -->|"3 · repo variables<br/>AWS_PLAN_ROLE_ARN<br/>AWS_APPLY_ROLE_ARN"| C["GitHub Actions"]
  B --> D["4 · envs/stg · envs/prod"]
  C --> D
```

```bash
export AWS_PROFILE=__AWS_PROFILE__

just bootstrap
# uncomment the backend block in shared/versions.tf
just migrate-state
just output shared      # -> set the two repository variables
```

## Permissions

```mermaid
graph LR
  H["engineer · AI agent"] -->|sts:AssumeRole| RO["__PREFIX__-terraform-readonly"]
  PR["pull request"] -->|OIDC| PL["__PREFIX__-terraform-plan"]
  WD["workflow_dispatch<br/>main or protected env"] -->|OIDC| AP["__PREFIX__-terraform-apply"]
```

## Commands

```bash
just                    # list recipes
just plan envs/stg
just plan-ro envs/prod  # readonly role: no state lock
just check              # fmt-check + validate, exactly what CI runs
```

PRs get a plan. Apply is `workflow_dispatch` only, behind a GitHub environment.
