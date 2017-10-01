.PHONY: all update build test run run_image bash tag push pull help kill clean
.DEFAULT_GOAL := help
SHELL = /bin/bash

# Docker Image Configuration
NAME            = ravada
NAMESPACE       = maneta 
RELEASE_VERSION ?= latest

LOCAL_IMAGE  := $(NAME):$(RELEASE_VERSION)
REMOTE_IMAGE := $(NAMESPACE)/$(LOCAL_IMAGE)

# Path Calculations
MKFILE_PATH  := $(abspath $(lastword $(MAKEFILE_LIST)))
THISDIR_PATH := $(patsubst %/,%,$(abspath $(dir $(MKFILE_PATH))))
PROJECT_PATH := $(patsubst %/,%,$(dir $(MKFILE_PATH)))

all: test update ## Test, Build and Push Docker Image to the Registry
update: build push ## Build and Push Docker Image to the Registry

build: ## Build docker image with name LOCAL_IMAGE (NAME:RELEASE_VERSION).
	docker build -f $(THISDIR_PATH)/Dockerfile -t $(LOCAL_IMAGE) $(PROJECT_PATH)

test: ## Test built LOCAL_IMAGE (NAME:RELEASE_VERSION).
	docker-compose run --rm -u 1001 \
		-e OAUTH_GITHUB_KEY=$(OAUTH_GITHUB_KEY) \
		-e OAUTH_GITHUB_SECRET=$(OAUTH_GITHUB_SECRET) \
		-e OAUTH_FACEBOOK_KEY=$(OAUTH_FACEBOOK_KEY) \
		-e OAUTH_FACEBOOK_SECRET=$(OAUTH_FACEBOOK_SECRET) \
		-e OAUTH_GOOGLE_KEY=$(OAUTH_GOOGLE_KEY) \
		-e OAUTH_GOOGLE_SECRET=$(OAUTH_GOOGLE_SECRET) \
		-e DB_HOST=$(DB_HOST) \
		-e DB_USER=$(DB_USER) \
		-e DB_PASS=$(DB_PASS) \
		--entrypoint=carton mojo exec prove -lv

run_image: build ## Run the Application Docker image in the local machine.
	docker run --rm -u 1001 --name mojo \
		-e OAUTH_GITHUB_KEY=$(OAUTH_GITHUB_KEY) \
		-e OAUTH_GITHUB_SECRET=$(OAUTH_GITHUB_SECRET) \
		-e OAUTH_FACEBOOK_KEY=$(OAUTH_FACEBOOK_KEY) \
		-e OAUTH_FACEBOOK_SECRET=$(OAUTH_FACEBOOK_SECRET) \
		-e OAUTH_GOOGLE_KEY=$(OAUTH_GOOGLE_KEY) \
		-e OAUTH_GOOGLE_SECRET=$(OAUTH_GOOGLE_SECRET) \
		-i -t -p 8080:8080 $(LOCAL_IMAGE)

run: build ## Run the Application Docker Compose in the local machine.
	ENVIRONMENT=$(ENVIRONMENT) \
	OAUTH_GITHUB_KEY=$(OAUTH_GITHUB_KEY) \
	OAUTH_GITHUB_SECRET=$(OAUTH_GITHUB_SECRET) \
	OAUTH_FACEBOOK_KEY=$(OAUTH_FACEBOOK_KEY) \
	OAUTH_FACEBOOK_SECRET=$(OAUTH_FACEBOOK_SECRET) \
	OAUTH_GOOGLE_KEY=$(OAUTH_GOOGLE_KEY) \
	OAUTH_GOOGLE_SECRET=$(OAUTH_GOOGLE_SECRET) \
	DB_HOST=$(DB_HOST) \
	DB_USER=$(DB_USER) \
	DB_PASS=$(DB_PASS) \
	docker-compose up --force-recreate

kill: ## Kill the compose in the local machine.
	docker-compose stop

bash: ## Start bash in the build IMAGE_NAME.
	docker-compose run --rm --entrypoint=/bin/bash mojo

bash_image: ## Start bash in the build IMAGE_NAME.
	docker run --privileged --rm --entrypoint=/bin/bash -it $(LOCAL_IMAGE)

tag: ## Tag IMAGE_NAME
	docker tag $(LOCAL_IMAGE) $(REMOTE_IMAGE)

push: tag ## Push to the docker registry
	docker push $(REMOTE_IMAGE)

pull: ## Pull the docker from the Registry
	docker pull $(REMOTE_IMAGE)

clean: ## Clean local images/files from this environment
	docker-compose rm -f
	docker rmi $(LOCAL_IMAGE) --force
	docker rmi postgres:9.6-alpine --force
	rm -rf ./pgdata
	rm -f ./conf/secrets.mk

# Check http://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
help: ## Print this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
