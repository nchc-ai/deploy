SUBMODULES_DIR_LS = $(shell ls -d */)


.PHONY: 
all: build load clean

build:
	git submodule update --init --recursive
	for dir in $(SUBMODULES_DIR_LS); do \
		$(MAKE) -C $$dir image; \
	done


load:
	@for dir in $(SUBMODULES_DIR_LS); do \
		dir=$${dir%/}; \
		cd $$dir; \
		commit_hash=`git rev-parse --short HEAD`; \
		ret=`git describe --contains $$commit_hash 1>&2 2> /dev/null; echo $$?`; \
		if [ $$ret -eq 0 ]; then \
			tag=`git describe --contains $$commit_hash`; \
		else \
			tag=HEAD; \
		fi; \
		kind load docker-image ghcr.io/nchc-ai/$$dir:$$tag; \
		cd ..; \
	done

clean:
	@for dir in $(SUBMODULES_DIR_LS); do \
		dir=$${dir%/}; \
		cd $$dir; \
		commit_hash=`git rev-parse --short HEAD`; \
		ret=`git describe --contains $$commit_hash 1>&2 2> /dev/null; echo $$?`; \
		if [ $$ret -eq 0 ]; then \
			tag=`git describe --contains $$commit_hash`; \
		else \
			tag=HEAD; \
		fi; \
		docker rmi ghcr.io/nchc-ai/$$dir:$$tag 2> /dev/null || true ; \
		cd ..; \
		find $$dir -mindepth 1 -delete; \
	done

update:
	git submodule update --remote --merge
