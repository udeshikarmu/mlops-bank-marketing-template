.PHONY: doctor dvc-auth lint format test repro experiments serve docker-build docker-run

doctor:  ## check that everything the workshop needs is ready
	@echo "=== Tools ==="
	@uv --version
	@uv run python --version
	@uv run dvc --version
	@docker --version
	@echo "=== DagsHub secrets ==="
	@test -n "$$DAGSHUB_OWNER" || (echo "DAGSHUB_OWNER is not set (Codespaces secret)" && exit 1)
	@test -n "$$DAGSHUB_TOKEN" || (echo "DAGSHUB_TOKEN is not set (Codespaces secret)" && exit 1)
	@uv run python -c "import os, sys, mlflow; \
		o, t = os.environ['DAGSHUB_OWNER'], os.environ['DAGSHUB_TOKEN']; r = os.environ.get('DAGSHUB_REPO') or 'mlops-bank-marketing'; \
		sys.exit('DAGSHUB_OWNER or DAGSHUB_TOKEN contains a hidden space or line break: retype the secret') if (o != o.strip() or t != t.strip()) else None; \
		os.environ.update(MLFLOW_TRACKING_URI=f'https://dagshub.com/{o}/{r}.mlflow', MLFLOW_TRACKING_USERNAME=o, MLFLOW_TRACKING_PASSWORD=t); \
		mlflow.search_experiments(max_results=1); print('MLflow OK:', mlflow.get_tracking_uri())"
	@echo "=== All checks passed ==="

dvc-auth:  ## point DVC at YOUR DagsHub repo and store your login (in .dvc/config.local, not in git)
	uv run dvc remote modify origin --local url "https://dagshub.com/$$DAGSHUB_OWNER/$${DAGSHUB_REPO:-mlops-bank-marketing}.dvc"
	uv run dvc remote modify origin --local auth basic
	uv run dvc remote modify origin --local user "$$DAGSHUB_OWNER"
	uv run dvc remote modify origin --local password "$$DAGSHUB_TOKEN"

lint:
	uv run ruff check .
	uv run ruff format --check .

format:
	uv run ruff check --fix .
	uv run ruff format .

test:
	uv run pytest -q

repro:
	uv run dvc repro

experiments:
	uv run python -m src.experiments

serve:
	uv run uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

docker-build:
	docker build --build-arg MODEL_VERSION=local -t bank-marketing:local .

docker-run:
	docker run --rm -p 8000:8000 bank-marketing:local