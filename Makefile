.PHONY: build shell irb

build:
	-rm -f Gemfile.lock
	docker build -t rollout-redis .
	@docker create --name tmp_rollout-redis rollout-redis >/dev/null 2>&1
	@docker cp tmp_rollout-redis:/rollout-redis/Gemfile.lock . >/dev/null 2>&1
	@docker rm tmp_rollout-redis >/dev/null 2>&1

test:
	docker run --rm -it -v $(PWD):/rollout-redis rollout-redis bundle exec rspec ${SPEC}

shell:
	docker run --rm -it -v $(PWD):/rollout-redis rollout-redis bash