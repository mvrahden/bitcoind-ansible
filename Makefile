IMAGE := bitcoind-ansible-test
DISTRO ?= ubuntu2004
BITCOIND_IMPL ?= core
BITCOIND_VERSION ?=

.PHONY: build test converge verify destroy clean

build:
	docker build -f Dockerfile.test -t $(IMAGE) .

test: build
	docker run --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v $(CURDIR):/role \
		-e MOLECULE_DISTRO=$(DISTRO) \
		-e BITCOIND_IMPL=$(BITCOIND_IMPL) \
		-e BITCOIND_VERSION=$(BITCOIND_VERSION) \
		$(IMAGE)

converge: build
	docker run --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v $(CURDIR):/role \
		-e MOLECULE_DISTRO=$(DISTRO) \
		-e BITCOIND_IMPL=$(BITCOIND_IMPL) \
		-e BITCOIND_VERSION=$(BITCOIND_VERSION) \
		$(IMAGE) converge

verify: build
	docker run --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v $(CURDIR):/role \
		-e MOLECULE_DISTRO=$(DISTRO) \
		-e BITCOIND_IMPL=$(BITCOIND_IMPL) \
		-e BITCOIND_VERSION=$(BITCOIND_VERSION) \
		$(IMAGE) verify

destroy: build
	docker run --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v $(CURDIR):/role \
		-e MOLECULE_DISTRO=$(DISTRO) \
		-e BITCOIND_IMPL=$(BITCOIND_IMPL) \
		-e BITCOIND_VERSION=$(BITCOIND_VERSION) \
		$(IMAGE) destroy

clean:
	-docker rmi $(IMAGE) 2>/dev/null
