.PHONY: bootstrap preflight start-test-env stop-test-env test-backend test-api test-frontend test-e2e verify verify-live harness-feature harness-status harness-stop

bootstrap:
	./scripts/bootstrap.sh

preflight:
	./scripts/harness-preflight.sh

start-test-env:
	./scripts/start-test-env.sh

stop-test-env:
	./scripts/stop-test-env.sh

test-backend:
	./scripts/test-backend.sh

test-api:
	./scripts/test-api.sh

test-frontend:
	./scripts/test-frontend.sh

test-e2e:
	./scripts/test-e2e.sh

verify:
	./scripts/verify.sh

verify-live:
	HARNESS_LIVE_OPENAI=1 IMAGE_PROVIDER=openai ./scripts/test-live-openai.sh

harness-feature:
	@if [ -z "$(FEATURE)" ]; then echo "Usage: make harness-feature FEATURE=<feature-name>"; exit 2; fi
	@if [ "$(LIVE)" = "1" ]; then ./.harness/run-feature.sh "$(FEATURE)" --live; else ./.harness/run-feature.sh "$(FEATURE)"; fi

harness-status:
	@if [ -z "$(FEATURE)" ]; then echo "Usage: make harness-status FEATURE=<feature-name>"; exit 2; fi
	./scripts/harness-status.sh "$(FEATURE)"

harness-stop:
	@if [ -z "$(FEATURE)" ]; then echo "Usage: make harness-stop FEATURE=<feature-name>"; exit 2; fi
	./.harness/stop-feature.sh "$(FEATURE)"
