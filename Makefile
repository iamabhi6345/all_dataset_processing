# Make all targets .PHONY
.PHONY: $(shell sed -n -e '/^$$/ { n ; /^[^ .\#][^ ]*:/ { s/:.*$$// ; p ; } ; }' $(MAKEFILE_LIST))

SHELL = /usr/bin/env bash
USER_NAME = $(shell whoami)
USER_ID = $(shell id -u)
HOST_NAME = $(shell hostname)

ifeq (, $(shell which docker-compose))
	DOCKER_COMPOSE_COMMAND = docker compose
else
	DOCKER_COMPOSE_COMMAND = docker-compose
endif

SERVICE_NAME = app
CONTAINER_NAME = abhishek-data-processing-container

DIRS_TO_VALIDATE = abhishek
DOCKER_COMPOSE_RUN = $(DOCKER_COMPOSE_COMMAND) run --rm $(SERVICE_NAME)
DOCKER_COMPOSE_EXEC = $(DOCKER_COMPOSE_COMMAND) exec $(SERVICE_NAME)

LOCAL_DOCKER_IMAGE_NAME = abhishek-data-processing
GCP_DOCKER_IMAGE_NAME = europe-west4-docker.pkg.dev/iamabhi45/abhishek/abhishek-data-processing
GCP_DOCKER_IMAGE_TAG := $(strip $(shell uuidgen))


export


# Returns true if the stem is a non-empty environment variable, or else raises an error.
guard-%:
	@#$(or ${$*}, $(error $* is not set))

## Generate final config. CONFIG_NAME=<config_name> has to be providded. For overrides use: OVERRIDES=<overrides>
generate-final-config: up guard-CONFIG_NAME
	$(DOCKER_COMPOSE_EXEC) python ./abhishek/generate_final_config.py --config-name $${CONFIG_NAME} --overrides docker_image_name=$(GCP_DOCKER_IMAGE_NAME) docker_image_tag=$(GCP_DOCKER_IMAGE_TAG) $${OVERRIDES}


## Generate final data processing config. For overrides use: OVERRIDES=<overrides>
generate-final-data-processing-config: up
	$(DOCKER_COMPOSE_EXEC) python ./abhishek/generate_final_config.py --config-name data_processing_config --overrides docker_image_name=$(GCP_DOCKER_IMAGE_NAME) docker_image_tag=$(GCP_DOCKER_IMAGE_TAG) $${OVERRIDES}


## Generate final tokenizer training config. For overrides use: OVERRIDES=<overrides>
generate-final-tokenizer-training-config: up
	$(DOCKER_COMPOSE_EXEC) python ./abhishek/generate_final_config.py --config-name tokenizer_training_config --overrides docker_image_name=$(GCP_DOCKER_IMAGE_NAME) docker_image_tag=$(GCP_DOCKER_IMAGE_TAG) $${OVERRIDES}


## Processes raw data
process-data: generate-final-data-processing-config push
	$(DOCKER_COMPOSE_EXEC) python ./abhishek/process_data.py

## Train a tokenizer
train-tokenizer: generate-final-tokenizer-training-config push
	$(DOCKER_COMPOSE_EXEC) python ./abhishek/train_tokenizer.py

## Processes raw data
local-process-data: generate-final-data-processing-config
	$(DOCKER_COMPOSE_EXEC) python ./abhishek/process_data.py


## Train a tokenizer locally
local-train-tokenizer: generate-final-tokenizer-training-config
	$(DOCKER_COMPOSE_EXEC) python ./abhishek/train_tokenizer.py


## test Processes raw data
test-process-data: up
	$(DOCKER_COMPOSE_EXEC) python ./abhishek/process_data.py




## Push docker image to GCP artifact registery
push: build
	gcloud auth configure-docker --quiet europe-west4-docker.pkg.dev
	docker tag $(LOCAL_DOCKER_IMAGE_NAME):latest "$(GCP_DOCKER_IMAGE_NAME):$(GCP_DOCKER_IMAGE_TAG)"
	docker push "$(GCP_DOCKER_IMAGE_NAME):$(GCP_DOCKER_IMAGE_TAG)"

## Starts jupyter lab
notebook: up
	$(DOCKER_COMPOSE_EXEC) jupyter-lab --ip 0.0.0.0 --port 8888 --no-browser

## Sort code using isort
sort: up
	$(DOCKER_COMPOSE_EXEC) isort --atomic $(DIRS_TO_VALIDATE)

## Check sorting using isort
sort-check: up
	$(DOCKER_COMPOSE_EXEC) isort --check-only --atomic $(DIRS_TO_VALIDATE)

## Format code using black
format: up
	$(DOCKER_COMPOSE_EXEC) black $(DIRS_TO_VALIDATE)

## Check format using black
format-check: up
	$(DOCKER_COMPOSE_EXEC) black --check $(DIRS_TO_VALIDATE)

## Format and sort code using black and isort
format-and-sort: sort format

## Lint code using flake8
lint: up format-check sort-check
	$(DOCKER_COMPOSE_EXEC) flake8 $(DIRS_TO_VALIDATE)

## Check type annotations using mypy
check-type-annotations: up
	$(DOCKER_COMPOSE_EXEC) mypy $(DIRS_TO_VALIDATE)

## Run tests with pytest
test: up
	$(DOCKER_COMPOSE_EXEC) pytest

## Perform a full check
full-check: lint check-type-annotations
	$(DOCKER_COMPOSE_EXEC) pytest --cov --cov-report xml --verbose

## Builds docker image
build:
	$(DOCKER_COMPOSE_COMMAND) build $(SERVICE_NAME)

## Remove poetry.lock and build docker image
build-for-dependencies:
	rm -f *.lock
	$(DOCKER_COMPOSE_COMMAND) build $(SERVICE_NAME)

## Lock dependencies with poetry
lock-dependencies: build-for-dependencies
	$(DOCKER_COMPOSE_RUN) bash -c "if [ -e /home/$(USER_NAME)/poetry.lock.build ]; then cp /home/$(USER_NAME)/poetry.lock.build ./poetry.lock; else poetry lock; fi"

## Starts docker containers using "docker-compose up -d"
up:
	$(DOCKER_COMPOSE_COMMAND) up -d

## docker-compose down
down:
	$(DOCKER_COMPOSE_COMMAND) down

## Open an interactive shell in docker container
exec-in: up
	docker exec -it $(CONTAINER_NAME) bash

.DEFAULT_GOAL := help



# Inspired by <http://marmelab.com/blog/2016/02/29/auto-documented-makefile.html>
# sed script explained:
# /^##/:
# 	* save line in hold space
# 	* purge line
# 	* Loop:
# 		* append newline + line to hold space
# 		* go to next line
# 		* if line starts with doc comment, strip comment character off and loop
# 	* remove target prerequisites
# 	* append hold space (+ newline) to line
# 	* replace newline plus comments by `---`
# 	* print line
# Separate expressions are necessary because labels cannot be delimited by
# semicolon; see <http://stackoverflow.com/a/11799865/1968>
.PHONY: help
help:
	@echo "$$(tput bold)Available rules:$$(tput sgr0)"
	@echo
	@sed -n -e "/^## / { \
		h; \
		s/.*//; \
		:doc" \
		-e "H; \
		n; \
		s/^## //; \
		t doc" \
		-e "s/:.*//; \
		G; \
		s/\\n## /---/; \
		s/\\n/ /g; \
		p; \
	}" ${MAKEFILE_LIST} \
	| LC_ALL='C' sort --ignore-case \
	| awk -F '---' \
		-v ncol=$$(tput cols) \
		-v indent=36 \
		-v col_on="$$(tput setaf 6)" \
		-v col_off="$$(tput sgr0)" \
	'{ \
		printf "%s%*s%s ", col_on, -indent, $$1, col_off; \
		n = split($$2, words, " "); \
		line_length = ncol - indent; \
		for (i = 1; i <= n; i++) { \
			line_length -= length(words[i]) + 1; \
			if (line_length <= 0) { \
				line_length = ncol - indent - length(words[i]) - 1; \
				printf "\n%*s ", -indent, " "; \
			} \
			printf "%s ", words[i]; \
		} \
		printf "\n"; \
	}' \
	| more $(shell test $(shell uname) = Darwin && echo '--no-init --raw-control-chars')




