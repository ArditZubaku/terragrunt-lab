# terragrunt-lab

The same tiny AWS app, deployed two ways, against LocalStack:

- **`plain-terraform/`** — plain Terraform, the way you already know it. Two environments (`dev`, `prod`), each a full copy-paste of four root modules.
- **`terragrunt/`** — the identical infrastructure, orchestrated with Terragrunt, structured the same way `Holocene-Devs/infra` structures it.

Both trees call the **same shared modules** in `modules/`. Nothing about the Terraform resource code differs between them — only how the two environments are wired together and how state/provider config is managed. That's deliberate: it isolates exactly what Terragrunt is buying you.

## The app

Four components, one event chain:

```
 SQS "ingest" queue --(event source mapping)--> ingest-lambda --(s3:PutObject)--> S3 "reports" bucket
                                                                                          |
                                                                            (S3 ObjectCreated event)
                                                                                          v
                                                                                   notify-lambda
                                                                                (logs to CloudWatch)
```

Dependency graph (this is what `terragrunt dag graph` outputs for either env):

```
storage         queue
  |  \            |
  |   \___________|
  |        |
  v        v
notify   ingest-lambda
-lambda
```

- `storage` — S3 bucket, no dependencies
- `queue` — SQS queue, no dependencies
- `ingest-lambda` — depends on **both** `storage` and `queue`
- `notify-lambda` — depends on `storage`

Four components was the minimum that gives a real two-dependency node (`ingest-lambda`) and a producer feeding two independent consumers (`storage`) — enough to make DAG ordering and `dependency` blocks actually mean something, without turning this into a real project.

## Prerequisites

- Docker
- `terraform` (this was built/tested against 1.16.3)
- `terragrunt` (1.1.6 — `brew install terragrunt`; this is the "Terragrunt CLI redesign" version, commands are `terragrunt apply`, `terragrunt run --all apply`, `terragrunt dag graph`, not the old `plan-all`/`apply-all`)
- `aws` CLI v2
- A LocalStack auth token in `.envrc` (`LOCALSTACK_AUTH_TOKEN=`) — see [Gotchas](#gotchas-hit-while-building-this), LocalStack now requires one even for community services. Free signup at app.localstack.cloud.

```bash
direnv allow   # or: source .envrc
make up        # docker compose up, waits for LocalStack health
make build     # zips the two Lambda handlers into build/
```

## Run it

```bash
# plain terraform: bootstraps the state bucket by hand, applies in manual order
make plain-apply-dev
make smoke-test-plain
make plain-destroy-dev

# terragrunt: bootstraps the state bucket by hand too (see gotchas), then
# one command walks the DAG for you
make tg-apply-dev
make smoke-test-tg
make tg-destroy-dev

# see the DAG terragrunt computed
make tg-graph
```

`smoke-test-*` sends one SQS message and polls S3 for the object `ingest-lambda` should have written — a real, if small, end-to-end proof the whole chain works, not just that `apply` succeeded.

Both trees use disjoint resource/bucket names (`terragrunt-lab-plain-*` vs `terragrunt-lab-tg-*`), so you can genuinely run both at once and compare, rather than having to tear one down to try the other.

## Side by side

| Concern | `plain-terraform/` | `terragrunt/` |
|---|---|---|
| Provider + backend config | Copy-pasted into **every** component × env (`main.tf`, ~35 lines each, 8 times) | Written **once** in `root.hcl`, injected via `generate` |
| Cross-component data | `data "terraform_remote_state"`, full backend config copy-pasted **again** per reference | `dependency "storage" { config_path = "../storage" }` — two lines |
| Apply ordering | You know it or you read the Makefile: storage, queue, then the lambdas | `terragrunt run --all apply` computes it from `dependency` blocks |
| Plan before a dependency exists | Fails outright, or you apply dependencies first | `mock_outputs` on each `dependency` block let `plan`/`validate` run standalone |
| State bucket | You create it by hand before the first `init` (`make plain-bootstrap-dev`) | Same here against LocalStack (see gotchas) — but against real AWS/GCS, `--backend-bootstrap` does it for you |
| Add a 3rd environment | Copy 4 directories, hand-edit every hardcoded value (~350+ new lines) | One `env.hcl` (~6 lines) + four 2-line include stubs |
| Lines of orchestration code | **8 files, 708 lines** | **15 files, 268 lines** |
| DAG visualization | None | `terragrunt dag graph` |

The module code itself (`modules/`, 12 files, 282 lines) is identical either way and isn't counted above — this table is purely the orchestration layer, which is the thing Terragrunt actually replaces.

## What each tree's files are doing

**`plain-terraform/dev/ingest-lambda/main.tf`** (and its `prod` twin) is the file that sells it. It has, in order: a full `backend "s3"` block, a full `provider "aws"` block, then **two** `data "terraform_remote_state"` blocks — one for `storage`, one for `queue` — each re-declaring the *entire* backend connection config just to read two output values. That's not bad style; it's what plain Terraform makes you do once you split a stack into independently-stated components. `terragrunt/_units/ingest-lambda.hcl` does the same job in a `dependency` block referencing a relative path.

**`terragrunt/root.hcl`** is the whole DRY win in one file: a `generate "provider"` block (LocalStack endpoints, written once) and a `remote_state` block (S3 backend, keyed per-unit, written once). Every leaf `terragrunt.hcl` inherits both by including it.

**`terragrunt/_units/*.hcl`** holds the actual per-component logic — `terraform.source`, `dependency` blocks, `inputs` — written **once per component**, not once per component-per-environment.

**`terragrunt/dev/storage/terragrunt.hcl`** (and its seven siblings) is two `include` blocks and nothing else. All the environment ever contributes is *which* `env.hcl` and `_units/*.hcl` get pulled in, by virtue of where the file sits in the directory tree.

## Gotchas hit while building this

These are real, not hypothetical — everything below is exactly what broke on the first `apply --all` and how it was fixed. Worth knowing before you hit them yourself:

1. **LocalStack now requires an auth token even for community services** (S3/SQS/Lambda/IAM are still free). `docker compose up` fails with a license error otherwise. Get a free token at app.localstack.cloud and put it in `.envrc`.

2. **`terragrunt run --all` / `apply --all` is current syntax**, not `plan-all`/`apply-all` (those are the pre-1.0 Terragrunt CLI). This lab was built against Terragrunt 1.1.6.

3. **Don't `generate` a `required_providers` block when `terraform.source` points straight at a module that already declares one.** The first version of `root.hcl` generated `terraform { required_providers { aws = ... } }` alongside the `provider "aws"` block. Since Terragrunt copies `modules/s3-bucket` (which has its own `versions.tf` with `required_providers`) into the same working directory it generates into, that's two `required_providers` blocks for `aws` in one module — Terraform refuses to init. Fix: `generate` only the `provider "aws" { ... }` block; let the sourced module's own `versions.tf` satisfy the requirement. (`required_version` doesn't have this restriction — only `required_providers` for the same provider, declared twice, errors.)

4. **`--backend-bootstrap` doesn't respect `use_path_style` against LocalStack.** Terragrunt can auto-create the state bucket on `init` — pass `--backend-bootstrap` — normally the standout DX win over plain Terraform's manual `aws s3 mb`. Against LocalStack specifically, the bootstrap codepath's `HeadBucket` precheck ends up issuing virtual-hosted-style requests (`HEAD /` with no bucket in the path) regardless of `use_path_style = true` in the backend config, and LocalStack answers with a bare `500` instead of the `404` Terragrunt expects. Against real AWS or GCS this isn't an issue — there, `--backend-bootstrap` genuinely is zero extra commands. Here, both trees bootstrap their state bucket the same way (`make tg-bootstrap-dev` / `make plain-bootstrap-dev`, both just `aws s3 mb`).

5. **Don't share `TF_PLUGIN_CACHE_DIR` across a `run --all` with real parallelism.** `storage` and `queue` have no dependency on each other, so Terragrunt correctly runs their `init` concurrently. Two concurrent `terraform init`s racing to populate the *same* shared plugin cache directory for the first time corrupted one provider binary (`exec format error`, then on retry a different unit hit `Failed to read any lines from plugin's stdout` — both are symptoms of a torn/partial binary from the race, not a real incompatibility). A second `run --all` succeeded immediately because the cache was already warm. This Makefile doesn't set `TF_PLUGIN_CACHE_DIR` by default for exactly this reason — each unit downloads into its own `.terragrunt-cache/`, which is slower but race-free. If you do want a shared cache for speed, Terragrunt's own `--provider-cache` flag is the race-safe way to get one (it runs a local caching proxy that serializes installs) — plain `TF_PLUGIN_CACHE_DIR` sharing is not safe under `run --all`'s parallelism.

6. **LocalStack Lambda pulls a real base image on first invoke.** The `python3.12` Lambda runtime image (`public.ecr.aws/lambda/python:3.12`) gets pulled via Docker the first time any function actually runs, not at `apply` time — the first `smoke-test` after a fresh `docker compose up` will be slower than subsequent ones.

## Mapping this back to `Holocene-Devs/infra`

This lab's `terragrunt/` tree is structured identically to the real repo, one level smaller:

| Here | There | Purpose |
|---|---|---|
| `terragrunt/root.hcl` | `live/root.hcl` | `remote_state` + `generate`, included by every unit |
| `terragrunt/_units/<unit>.hcl` | `live/_units/<unit>.hcl` | The unit's actual logic — `terraform.source`, `dependency` blocks, `inputs` — written once, shared across environments |
| `terragrunt/dev/env.hcl` | `live/staging/env.hcl` | Per-environment locals (`state_bucket`, region, name prefix) |
| `terragrunt/dev/storage/terragrunt.hcl` | `live/staging/data/terragrunt.hcl` | Thin leaf: two `include` blocks, nothing else |
| `modules/s3-bucket` etc. | `components/data` etc. | The actual Terraform resource code |

The `locals` idiom in every `_units/*.hcl` file —

```hcl
locals {
  unit_dir   = get_original_terragrunt_dir()
  env_dir    = dirname(local.unit_dir)
  env_config = read_terragrunt_config("${local.env_dir}/env.hcl")
  env        = local.env_config.locals
}
```

— is copied verbatim from `live/_units/data.hcl`. `get_original_terragrunt_dir()` (not `get_terragrunt_dir()`) is what makes it resolve correctly from inside a file that's included via an explicit path rather than `find_in_parent_folders()`; `root.hcl` itself uses plain `get_terragrunt_dir()` because it's only ever reached via `find_in_parent_folders()`, a single-include position where that's safe.

One real difference: `live/root.hcl` has **no `generate "provider"` block at all** — Holocene's services authenticate to GCP via WIF/ADC, so there are no static credentials to template, and each component's own `providers.tf` is committed instead of generated. This lab generates a provider block because LocalStack needs an explicit `endpoints {}` override — that's a property of talking to LocalStack, not something the real repo needs or does.

## Cleanup

```bash
make plain-destroy-dev
make tg-destroy-dev
# and/or -prod if you applied those
make down     # docker compose down -v
make clean    # removes build/, .terraform/, .terragrunt-cache/
```
