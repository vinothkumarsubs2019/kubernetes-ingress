all: push

VERSION = edge
TAG = $(VERSION)
PREFIX = nginx/nginx-ingress

DOCKER_TEST_RUN = docker run --rm -v $(shell pwd):/go/src/github.com/nginxinc/kubernetes-ingress -w /go/src/github.com/nginxinc/kubernetes-ingress
GOLANG_CONTAINER = golang:1.13
DOCKERFILEPATH = build
DOCKERFILE = Dockerfile # note, this can be overwritten e.g. can be DOCKERFILE=DockerFileForPlus

PUSH_TO_GCR =
GENERATE_DEFAULT_CERT_AND_KEY =
DOCKER_BUILD_OPTIONS =

GIT_COMMIT=$(shell git rev-parse --short HEAD)

export DOCKER_BUILDKIT = 1

lint:
	golangci-lint run

verify-codegen:
	./hack/verify-codegen.sh

update-codegen:
	./hack/update-codegen.sh

certificate-and-key:
ifeq ($(GENERATE_DEFAULT_CERT_AND_KEY),1)
	./build/generate_default_cert_and_key.sh
endif

binary:
	CGO_ENABLED=0 GO111MODULE=on GOFLAGS='-mod=vendor' GOOS=linux go build -installsuffix cgo -ldflags "-w -X main.version=${VERSION} -X main.gitCommit=${GIT_COMMIT}" -o nginx-ingress github.com/nginxinc/kubernetes-ingress/cmd/nginx-ingress

local-container: binary verify-codegen certificate-and-key
	GO111MODULE=on GOFLAGS='-mod=vendor' go test ./...
	docker build $(DOCKER_BUILD_OPTIONS) --build-arg IC_VERSION=$(VERSION)-$(GIT_COMMIT) --target local -f $(DOCKERFILEPATH)/$(DOCKERFILE) -t $(PREFIX):$(TAG) .

container: certificate-and-key
	$(DOCKER_TEST_RUN) -e GO111MODULE=on -e GOFLAGS='-mod=vendor' $(GOLANG_CONTAINER) go test ./...
	docker build $(DOCKER_BUILD_OPTIONS) --build-arg IC_VERSION=$(VERSION)-$(GIT_COMMIT) --target container -f $(DOCKERFILEPATH)/$(DOCKERFILE) -t $(PREFIX):$(TAG) .

push: container
ifeq ($(PUSH_TO_GCR),1)
	gcloud docker -- push $(PREFIX):$(TAG)
else
	docker push $(PREFIX):$(TAG)
endif

clean:
	rm -f nginx-ingress
