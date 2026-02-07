IMAGE := bitcoind-ansible-test
DISTRO ?= ubuntu2004

.PHONY: build test converge verify destroy clean

build:
	docker build -f Dockerfile.test -t $(IMAGE) .

test: build
	docker run --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v $(CURDIR):/role \
		-e MOLECULE_DISTRO=$(DISTRO) \
		$(IMAGE)

converge: build
	docker run --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v $(CURDIR):/role \
		-e MOLECULE_DISTRO=$(DISTRO) \
		$(IMAGE) converge

verify: build
	docker run --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v $(CURDIR):/role \
		-e MOLECULE_DISTRO=$(DISTRO) \
		$(IMAGE) verify

destroy: build
	docker run --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v $(CURDIR):/role \
		-e MOLECULE_DISTRO=$(DISTRO) \
		$(IMAGE) destroy

clean:
	-docker rmi $(IMAGE) 2>/dev/null
