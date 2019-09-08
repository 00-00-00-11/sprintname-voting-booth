
export PATH:=$(PATH):$(shell npm bin)
SHELL:=bash

ENVIRONMENT=$(shell if test -r .env && which jq >/dev/null 2>&1; then jq -r .environment .env; fi)
NEXT_VERSION=$(shell git tag | awk '{ sub(/^v/, ""); if (0 + $$1 > max) max = $$1; } END { printf "%.1f", max + 0.1 }')
NEXT_TAG=v$(NEXT_VERSION)
CURRENT_VERSION=$(shell git describe --tags | sed -e 's/^v//')
CURRENT_TAG=$(shell git describe --tags)

# detect GNU and BSD sed (GNU supports --version)
SED_OPTS=$(shell if sed --version >/dev/null 2>&1; then echo '-i -e'; else echo '-i "" -E'; fi)

JS_SOURCE=jssrc
ELM_SOURCE=src
DIST=dist
SERVICE_WORKER=$(DIST)/service-worker.js

DOCKER_REGISTRY=eu.gcr.io/proforto-team-sso
SERVERREGEX=[v]oting-booth
DOCKER_REPO=voting-booth
DOCKERPORTS=-p 4201:4201

KUBE_NAMESPACE=voting-booth
KUBE_CONTEXT=voting-booth
KUBE_DEPLOYMENT=voting-booth
KUBE_RESTART_PATCH=$(shell node kubernetes/restartdate_patch.js)

.DEFAULT_GOAL:=help

############################################################################
##@ Generic:

# automatic self-documentation
.PHONY: help # See https://gist.github.com/ruittenb/5d2d281237385276f49652b9b9f6d5a1
help: ## display this help
	@awk -v tab=24 'BEGIN { FS = ":.*## "; buffer = ""; color = "\033[36m"; nocolor = "\033[0m"; indent = "  "; usage(); } function trim(str) { gsub(/[ \t]+$$/, "", str); gsub(/^[ \t]+/, "", str); return str; } function spout(target, desc) { split(trim(target), fields, " "); for (i in fields) printf "%s%s%-" tab "s%s%s\n", indent, color, trim(fields[i]), nocolor, desc; } function usage() { printf "\nUsage:\n%smake %s<target>%s\n\nRecognized targets:\n", indent, color, nocolor; } /\\$$/ { gsub(/\\$$/, ""); buffer = buffer $$0; next; } buffer { $$0 = buffer $$0; buffer = ""; } /^[-a-zA-Z0-9*%_. ]+:.*## / { pad = sprintf("\n%" tab "s" indent, ""); gsub(/\\n/, pad); spout($$1, $$2); } /^##@ / { gsub(/\\n/, "\n"); printf "\n%s\n", substr($$0, 5) } END { print "" }' $(MAKEFILE_LIST) # v1.53

############################################################################
##@ Development:

.PHONY: install
install: ## install all npm dependencies
	npm install

.PHONY: build-elm
build-elm: ## compile elm files to javascript
	elm-make $(ELM_SOURCE)/Main.elm --yes --output $(JS_SOURCE)/Elm.js

.PHONY: build-bundle
build-bundle: ## bundle javascript files
	test "$(ENVIRONMENT)" = development &&                               \
		browserify $(JS_SOURCE)/app.js -o $(JS_SOURCE)/bundle.js ||  \
		browserify $(JS_SOURCE)/app.js                               \
			-g [ envify --NODE_ENV $${ENVIRONMENT:-production} ] \
			-g uglifyify -o $(JS_SOURCE)/bundle.js

.PHONY: build-do-minify
build-do-minify:
	uglifyjs $(JS_SOURCE)/bundle.js                                           \
		--compress "pure_funcs=['F2','F3','F4','F5','F6','F7','F8','F9']" \
		--mangle --output $(DIST)/bundle.js

.PHONY: build-minify
build-minify: ## minify javascript bundle (unless on development)
	test "$(ENVIRONMENT)" = development &&                 \
		cp $(JS_SOURCE)/bundle.js $(DIST)/bundle.js || \
		make build-do-minify

.PHONY: build
build: version build-elm build-bundle build-minify ## all of the build steps above

.PHONY: prod
prod: ## mark environment as 'production'
	cp .env.production .env

.PHONY: devel
devel: ## mark environment as 'development'
	cp .env.development .env

.PHONY: version
version: ## update the version file with the current git tag name
	-which git >/dev/null 2>&1 \
		&& echo "jQuery(document).ready(function () { jQuery('#version').prepend('$(CURRENT_TAG)'); });" > $(JS_SOURCE)/version.js

.PHONY: bump
bump: ## increment the version in the serviceworker by 0.0.1
	perl -i'' -pe 's/^(const version = .v\d+\.\d\.)(\d+)(.;)/$$1 . ($$2 + 1) . $$3/e' $(SERVICE_WORKER)

.PHONY: tag
tag: ## create git tag, next in line (with 0.1 increments) and push to repo
	sed $(SED_OPTS) "s/^(const version = ')v[^']*(';)/\1$(NEXT_TAG).0\2/" $(SERVICE_WORKER)
	sed $(SED_OPTS) 's/^(  "version": ")[^"]*(",)/\1$(NEXT_VERSION).0\2/' package.json
	git commit $(SERVICE_WORKER) package.json -m 'Updated files with new tag'
	git tag $(NEXT_TAG)
	make version
	git push
	git push --tags

.PHONY: rmtag
rmtag: ## remove a tag erroneously created (current tag only)
	git push origin --delete $(CURRENT_TAG)
	git tag --delete $(CURRENT_TAG)

############################################################################
##@ Webserver:

.PHONY: show-err
show-err: # iTerm2 tab coloring
	@printf '\033]6;1;bg;red;brightness;128\a'
	@printf '\033]6;1;bg;green;brightness;0\a'

.PHONY: show-busy
show-busy: # iTerm2 tab coloring
	@printf '\033]6;1;bg;red;brightness;128\a'
	@printf '\033]6;1;bg;green;brightness;128\a'

.PHONY: show-ok
show-ok: # iTerm2 tab coloring
	@printf '\033]6;1;bg;red;brightness;0\a'
	@printf '\033]6;1;bg;green;brightness;128\a'

.PHONY: show-none
show-none: # iTerm2 tab coloring
	@printf '\033]6;1;bg;*;default\a'

.PHONY: start
start: build ## start the webserver
	npm start

.PHONY: stop
stop: ## stop the webserver
	npm stop

.PHONY: status
status: ## show the webserver status
	@ps -ef | grep -s $(SERVERREGEX) || true

.PHONY: restart
restart: stop start ## restart the webserver

.PHONY: watch
watch: ## start the webserver. rebuild and restart if the source changes
	(                                                                       \
		trap 'make show-none; exit' INT;                                \
		while make bump build && make show-ok || make show-err; do      \
			npm start &                                             \
			rm $(JS_SOURCE)/bundle.js.tmp-browserify-* 2>/dev/null; \
			fswatch --one-event $(ELM_SOURCE) $(JS_SOURCE)          \
				$(SERVICE_WORKER) tokenserver;                  \
			make show-busy;                                         \
			echo 'Changes detected, rebuilding...';                 \
			npm stop;                                               \
		done                                                            \
	)

############################################################################
##@ Building and running in docker locally:

.PHONY: docker-build
docker-build: ## build the docker image
	nice docker build -t $(DOCKER_REGISTRY)/$(DOCKER_REPO):latest .

.PHONY: docker-status
docker-status: ## show the status of the docker image and containers
	@echo IMAGES
	@docker images | grep $(DOCKER_REPO) || echo none
	@echo CONTAINERS
	@docker ps -a  | grep $(DOCKER_REPO) || echo none

.PHONY: docker-tag
docker-tag: ## tag the :latest docker image with the current version
	docker image tag $(DOCKER_REGISTRY)/$(DOCKER_REPO):latest $(DOCKER_REGISTRY)/$(DOCKER_REPO):$(CURRENT_VERSION)

.PHONY: docker-start
docker-start: ## start the docker container
	if docker ps -a | grep $(SERVERREGEX) >/dev/null 2>&1; then  \
		docker start $(DOCKER_REPO);                         \
	else                                                         \
		docker run --name $(DOCKER_REPO) $(DOCKERPORTS) -d   \
			-t $(DOCKER_REGISTRY)/$(DOCKER_REPO):latest  \
	fi

.PHONY: docker-build-start
docker-build-start: docker-build docker-start ## build the docker image and start a container

.PHONY: docker-stop
docker-stop: ## stop the docker container
	-docker stop $(DOCKER_REPO)

.PHONY: docker-destroy
docker-destroy: docker-stop ## destroy the docker image and container
	-docker rm -f $(DOCKER_REPO)
	-docker rmi $(DOCKER_REGISTRY)/$(DOCKER_REPO):latest

.PHONY: docker-shell
docker-shell: ## shell into the running docker container
	docker exec -it $(DOCKER_REPO) /bin/bash

.PHONY: docker-clean
docker-clean:
	docker images | awk -v current_version=$(CURRENT_VERSION) -v docker_repo=$(DOCKER_REPO) ' \
		$$0 ~ docker_repo && $$2 != "latest" && $$2 != current_version { print $$3 }      \
	' | xargs docker rmi

############################################################################
##@ Publishing and deployment on Kubernetes:

.PHONY: docker-push
docker-push: ## push the current image tag to docker repo
	docker push $(DOCKER_REGISTRY)/$(DOCKER_REPO):$(CURRENT_VERSION)

.PHONY: kube-switch-context
kube-switch-context: ## switch kubernetes context to voting-booth
	kubectl config use-context $(KUBE_CONTEXT)

.PHONY: kube-edit-deployment
kube-edit-deployment: ## edit the deployment in an editor, to increment version number
	@echo "Please increment the version number in the deployment to $(CURRENT_VERSION)"
	@read -p "Press Enter now to start your editor: " ans
	kubectl edit deployment $(KUBE_DEPLOYMENT) -n $(KUBE_NAMESPACE)

.PHONY: kube-restart-production
kube-restart-production: ## gracefully restart kubernetes pod
	kubectl patch deployment $(KUBE_DEPLOYMENT) -n $(KUBE_NAMESPACE) -p '$(KUBE_RESTART_PATCH)'

.PHONY: kube-deploy-production
kube-deploy-production: docker-build docker-tag docker-push kube-edit-deployment kube-restart-production \
## build docker image, tag it, push to docker repo and restart production pod

############################################################################

# vim: set list ts=8 sw=8 noet:
