all: vulnerable-linux-driver-db.zip

ifeq (, $(shell which docker))
$(error "No docker in $(PATH), consider installing docker")
endif

.docker-build:
	docker build -t codeql-cli .
	touch .docker-build

vulnerable_linux_driver/Makefile.orig: .docker-build
	$(eval BUILD_PATH=$(shell docker run --entrypoint=/bin/bash codeql-cli -c 'find /lib/modules -name build' | sed 's/\//\\\//g'))
	sed -i .orig 's/\/lib\/modules\/`uname -r`\/build/$(BUILD_PATH)/g' vulnerable_linux_driver/Makefile
vulnerable-linux-driver-db.zip: .docker-build vulnerable_linux_driver/Makefile.orig
	docker run -v "$(PWD):/data" codeql-cli database create --overwrite -l cpp -s /data/vulnerable_linux_driver /data/vulnerable-linux-driver-db
	docker run -v "$(PWD):/data" codeql-cli database bundle -o /data/vulnerable-linux-driver.zip /data/vulnerable-linux-driver-db
	rm -rf vulnerable-linux-driver-db

.PHONY: clean
clean:
	rm -f vulnerable-linux-driver.zip
	docker image rm --force codeql-cli
	rm -f .docker-build
	git -C vulnerable_linux_driver restore Makefile
	git -C vulnerable_linux_driver clean -f
	rm -f vulnerable_linux_driver/Makefile.orig