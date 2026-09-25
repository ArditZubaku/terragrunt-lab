up:
	docker compose up -d
	@echo "waiting for LocalStack..."
	@until curl -sf http://localhost:4566/_localstack/health > /dev/null 2>&1; do sleep 1; done
	@echo "LocalStack is up"

down:
	docker compose down -v

logs:
	docker compose logs -f localstack

build:
	./lambda-src/build.sh

# --- plain terraform: manual state-bucket bootstrap, manual apply ordering ---

plain-bootstrap-dev:
	aws --endpoint-url http://localhost:4566 s3 mb s3://terragrunt-lab-plain-dev-tfstate || true

plain-bootstrap-prod:
	aws --endpoint-url http://localhost:4566 s3 mb s3://terragrunt-lab-plain-prod-tfstate || true

plain-apply-dev: build plain-bootstrap-dev
	cd plain-terraform/dev/storage && terraform init -input=false && terraform apply -auto-approve
	cd plain-terraform/dev/queue && terraform init -input=false && terraform apply -auto-approve
	cd plain-terraform/dev/ingest-lambda && terraform init -input=false && terraform apply -auto-approve
	cd plain-terraform/dev/notify-lambda && terraform init -input=false && terraform apply -auto-approve

plain-destroy-dev:
	cd plain-terraform/dev/notify-lambda && terraform destroy -auto-approve
	cd plain-terraform/dev/ingest-lambda && terraform destroy -auto-approve
	cd plain-terraform/dev/queue && terraform destroy -auto-approve
	cd plain-terraform/dev/storage && terraform destroy -auto-approve

plain-apply-prod: build plain-bootstrap-prod
	cd plain-terraform/prod/storage && terraform init -input=false && terraform apply -auto-approve
	cd plain-terraform/prod/queue && terraform init -input=false && terraform apply -auto-approve
	cd plain-terraform/prod/ingest-lambda && terraform init -input=false && terraform apply -auto-approve
	cd plain-terraform/prod/notify-lambda && terraform init -input=false && terraform apply -auto-approve

plain-destroy-prod:
	cd plain-terraform/prod/notify-lambda && terraform destroy -auto-approve
	cd plain-terraform/prod/ingest-lambda && terraform destroy -auto-approve
	cd plain-terraform/prod/queue && terraform destroy -auto-approve
	cd plain-terraform/prod/storage && terraform destroy -auto-approve

# --- terragrunt: ordering is handled for you. Bucket bootstrap normally is
# too (--backend-bootstrap) but that codepath doesn't respect use_path_style
# against LocalStack's non-DNS-based S3 addressing, so it's one manual `mb`
# here too -- see README caveats.

tg-bootstrap-dev:
	aws --endpoint-url http://localhost:4566 s3 mb s3://terragrunt-lab-tg-dev-tfstate || true

tg-bootstrap-prod:
	aws --endpoint-url http://localhost:4566 s3 mb s3://terragrunt-lab-tg-prod-tfstate || true

tg-apply-dev: build tg-bootstrap-dev
	cd terragrunt/dev && terragrunt apply --all --non-interactive

tg-destroy-dev:
	cd terragrunt/dev && terragrunt destroy --all --non-interactive

tg-apply-prod: build tg-bootstrap-prod
	cd terragrunt/prod && terragrunt apply --all --non-interactive

tg-destroy-prod:
	cd terragrunt/prod && terragrunt destroy --all --non-interactive

tg-graph:
	cd terragrunt/dev && terragrunt dag graph

smoke-test-plain:
	./scripts/smoke-test.sh terragrunt-lab-plain-dev-ingest terragrunt-lab-plain-dev-reports

smoke-test-tg:
	./scripts/smoke-test.sh terragrunt-lab-tg-dev-ingest terragrunt-lab-tg-dev-reports

clean:
	rm -rf build lambda-src/dist
	find plain-terraform terragrunt -type d \( -name .terraform -o -name .terragrunt-cache \) -prune -exec rm -rf {} +
