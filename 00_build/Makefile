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
		kind load docker-image ghcr.io/nchc-ai/$$dir:HEAD; \
	done

clean:
	@for dir in $(SUBMODULES_DIR_LS); do \
		find $$dir -mindepth 1 -delete; \
		dir=$${dir%/}; \
		docker rmi ghcr.io/nchc-ai/$$dir:HEAD 2> /dev/null || true ; \
	done

update:
	git submodule update --remote --merge
