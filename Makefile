.PHONY: build docker push clean
.SILENT: docker

SHELL = bash

ORG := eriksf
CUDA := 11.7.1
VER := ubuntu18.04-cuda11-tf2.11-pt1.13-mvapich2.3-ib

BUILD = docker build --build-arg CUDA=$(CUDA) -t $(ORG)/tacc-ml-mpi:$(VER)

####################################
# CFLAGS
####################################
DEFAULT := -O2 -pipe -march=x86-64 -ftree-vectorize
# Haswell doesn't exist in all gcc versions
TACC := $(DEFAULT) -mtune=core-avx2

####################################
# Sanity checks
####################################
docker:
	docker info 1> /dev/null 2> /dev/null && \
	if [ ! $$? -eq 0 ]; then \
		echo "\n[ERROR] Could not communicate with docker daemon. You may need to run with sudo.\n"; \
		exit 1; \
	fi

####################################
# MPI/ML Images
####################################
build: | docker
	$(BUILD) --build-arg FLAGS="$(TACC)" .

push: | docker
	docker push $(ORG)/tacc-ml-mpi:$(VER)

clean: | docker
	docker rmi $(ORG)/tacc-ml-mpi:$(VER)

