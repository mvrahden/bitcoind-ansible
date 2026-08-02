IMAGE := bitcoind-ansible-test
DISTRO ?= debian12
BITCOIND_IMPL ?= core
BITCOIND_VERSION ?=
SCENARIO ?= default
# Used by the upgrade scenario only.
BITCOIND_VERSION_FROM ?=
BITCOIND_VERSION_TO ?=

.PHONY: build test converge verify destroy lint clean

build:
	docker build -f Dockerfile.test -t $(IMAGE) .

test: build
	docker run --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v $(CURDIR):/role \
		-e MOLECULE_DISTRO=$(DISTRO) \
		-e BITCOIND_IMPL=$(BITCOIND_IMPL) \
		-e BITCOIND_VERSION=$(BITCOIND_VERSION) \
		-e BITCOIND_VERSION_FROM=$(BITCOIND_VERSION_FROM) \
		-e BITCOIND_VERSION_TO=$(BITCOIND_VERSION_TO) \
		$(IMAGE) test -s $(SCENARIO)

converge: build
	docker run --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v $(CURDIR):/role \
		-e MOLECULE_DISTRO=$(DISTRO) \
		-e BITCOIND_IMPL=$(BITCOIND_IMPL) \
		-e BITCOIND_VERSION=$(BITCOIND_VERSION) \
		-e BITCOIND_VERSION_FROM=$(BITCOIND_VERSION_FROM) \
		-e BITCOIND_VERSION_TO=$(BITCOIND_VERSION_TO) \
		$(IMAGE) converge -s $(SCENARIO)

verify: build
	docker run --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v $(CURDIR):/role \
		-e MOLECULE_DISTRO=$(DISTRO) \
		-e BITCOIND_IMPL=$(BITCOIND_IMPL) \
		-e BITCOIND_VERSION=$(BITCOIND_VERSION) \
		-e BITCOIND_VERSION_FROM=$(BITCOIND_VERSION_FROM) \
		-e BITCOIND_VERSION_TO=$(BITCOIND_VERSION_TO) \
		$(IMAGE) verify -s $(SCENARIO)

destroy: build
	docker run --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v $(CURDIR):/role \
		-e MOLECULE_DISTRO=$(DISTRO) \
		-e BITCOIND_IMPL=$(BITCOIND_IMPL) \
		-e BITCOIND_VERSION=$(BITCOIND_VERSION) \
		-e BITCOIND_VERSION_FROM=$(BITCOIND_VERSION_FROM) \
		-e BITCOIND_VERSION_TO=$(BITCOIND_VERSION_TO) \
		$(IMAGE) destroy -s $(SCENARIO)

lint: build
	docker run --rm -v $(CURDIR):/role --entrypoint yamllint $(IMAGE) .
	docker run --rm -v $(CURDIR):/role --entrypoint ansible-lint $(IMAGE)

clean:
	-docker rmi $(IMAGE) 2>/dev/null
