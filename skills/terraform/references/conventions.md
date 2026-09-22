# Boilerplate conventions

Contents: [Layout](#layout) · [State](#state) · [Where things go](#where-things-go) ·
[Modules](#modules) · [Commands and CI](#commands-and-ci) ·
[Permissions](#permissions) · [Bootstrap](#bootstrap) · [Style](#style)

## Layout

```
shared/           applied once: state bucket, GitHub OIDC provider,
                  readonly/plan/apply roles, account-wide IAM
envs/<env>/       one root module per environment (stg, prod)
modules/<name>/   reusable, consumed via `source = "../../modules/<name>"`
scripts/          aws-inventory.sh: read-only sweep → import scaffolding
justfile          every command; CI runs the same recipes
```

A **stack** is a directory. Environments are separated by directory, never by
`terraform workspace`. All environments may share one AWS account, so every
resource name carries the environment (`<prefix>-<env>-...`) and
`allowed_account_ids` pins the account in every provider block.

## State

- One S3 bucket for every stack, keyed by path: `shared/terraform.tfstate`,
  `envs/<env>/terraform.tfstate`.
- Locking is native: `use_lockfile = true`, no DynamoDB table. It requires
  `required_version = ">= 1.11"` (experimental in 1.10).
- The bucket has versioning, `prevent_destroy`, a TLS-only policy and
  noncurrent-version expiry. It is the only way back from a bad state push.
- `shared/` bootstraps on local state because it creates the bucket; see
  [Bootstrap](#bootstrap).

## Where things go

| New thing | Goes in |
|---|---|
| Resource used by one environment | `envs/<env>/main.tf` (or a topic file like `iam.tf`) |
| Account-wide IAM, users, cross-env policies | `shared/` |
| Pattern repeated across envs | `modules/<name>/`, called from each env |
| Import blocks during adoption | `<stack>/imports.tf`, deleted once applied |
| Adopted policy documents | `<stack>/policies/<name>.json`, verbatim |

- Environment values live in a `locals` block at the top of `envs/<env>/main.tf`
  (`env`, `account_id`, `region`, CIDRs). Resources owned elsewhere (e.g. a
  CloudFormation stack) are referenced from a `local` map of IDs.
- Maps, not lists, for anything keyed (subnets by AZ, rules by name): deleting
  one list element renumbers the rest and Terraform recreates them.
- A new environment: copy `envs/stg/`, change `local.env`, the backend `key`
  and the CIDRs, add the stack to the justfile's `stacks` and to the CI matrix.

## Modules

- Each module has `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf` and no
  provider block. Its provider lock file is gitignored; lock files are
  committed only in root stacks.
- Hardened by default: encryption on, IMDSv2 required, no public IPs, rules as
  standalone `aws_vpc_security_group_{ingress,egress}_rule` resources (inline
  rule blocks churn every plan and cannot be imported one at a time).
- Adoption knobs (`manage_*`, `tag_*`, `add_name_tag`, `name_overrides`,
  `root_volume_encrypted`, `disable_api_termination`, ...) exist so a live
  resource can be imported unchanged. **Every knob defaults to the hardened
  greenfield behaviour**; a new knob must too, so existing callers still plan
  clean. After changing a module, re-plan every stack that uses it.
- `create_before_destroy` on security groups; `ignore_changes = [ami, user_data]`
  on hosts (they are pets; a new AMI must not silently replace a running host).

## Commands and CI

```bash
export AWS_PROFILE=<profile>     # CI uses OIDC and sets no profile
just init envs/stg
just plan envs/stg               # extra flags pass through: -target=module.x
just plan-ro envs/prod           # readonly role: cannot take the lock
just check                       # fmt-check + validate (offline), what CI runs
just fmt · just lint             # tflint --recursive
just inventory                   # scripts/aws-inventory.sh (read-only)
```

- CI (`.github/workflows/terraform.yml`): `validate` needs no credentials;
  pull requests plan every stack under the plan role; apply is
  `workflow_dispatch` only, gated by a GitHub environment (`stg` for
  `envs/stg`, `prod` for everything else, `shared/` included).
- Anything CI runs must be a `just` recipe, so local and CI never diverge.
- Pause the `pull_request` trigger while a stack carries import blocks that a
  shared runner would evaluate against live AWS; restore it after.

## Permissions

| Role | Who | Can |
|---|---|---|
| `<prefix>-terraform-readonly` | engineers, AI agents | `ReadOnlyAccess` minus secret/parameter values, `kms:Decrypt`, and assuming plan/apply |
| `<prefix>-terraform-plan` | PR workflow via OIDC | the same + read state + write `*.tflock` only |
| `<prefix>-terraform-apply` | `workflow_dispatch` from `main` or a protected environment | apply |

`ReadOnlyAccess` includes `secretsmanager:GetSecretValue`; the
`deny-sensitive-reads` policy subtracts it. So a
`data "aws_secretsmanager_secret_version"` fails at plan -- deliberately, since
values read at plan time land in state.

## Bootstrap

```bash
just bootstrap                  # shared/ on local state; creates the bucket
# uncomment the backend "s3" block in shared/versions.tf
just migrate-state              # move shared/ state into the bucket
just output shared              # → AWS_PLAN_ROLE_ARN, AWS_APPLY_ROLE_ARN repo variables
```

Do apply and migrate in one sitting; until then state sits on one laptop.
If the account already has a GitHub OIDC provider, creating it fails with
`EntityAlreadyExists`: import it instead.

## Style

- Comments: one or two lines, only the non-obvious *why* or a trap.
- `terraform fmt` clean; `tflint` recommended preset + AWS ruleset.
- Docs favour diagrams over prose.
