PROJECT = $(CURDIR)

all: build

.PHONY: clean build

clean:
	rm -rf build
	rm -rf site-packages

build:
	$(info ************ Starting Build: $(PROJECT) ************)
	mkdir -p site-packages
	cp *.* ./site-packages
	cp -r tools ./site-packages
	mkdir -p build
	python3 -m venv build/
	. build/bin/activate; \
	pip3 install  -r requirements.txt -t ./site-packages;
	rm -rf build
