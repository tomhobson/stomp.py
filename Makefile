PYTHON:=`which python`
DESTDIR=/
PROJECT=stomp.py
PYTHON_VERSION_MAJOR:=$(shell $(PYTHON) -c "import sys;print(sys.version_info[0])")
PLATFORM := $(shell uname)


all:
	@echo "make source - Create source package"
	@echo "make install - Install on local system"
	@echo "make buildrpm - Generate a rpm package"
	@echo "make builddeb - Generate a deb package"
	@echo "make clean - Get rid of scratch and byte files"

.PHONY: docs

docs:
	cd docs && make html

updateversion:
	poetry version `python -c "import stomp; print('.'.join(map(str, stomp.__version__)))"`

install: updateversion
	poetry update
	poetry build
	poetry export -f requirements.txt --dev -o requirements.txt

test:
	poetry run pytest tests/ --cov=stomp --log-cli-level=DEBUG -v -ra --full-trace --cov-report=html:../stomppy-docs/htmlcov/ --html=tmp/report.html

#buildrpm:
#	$(PYTHON) setup.py bdist_rpm --post-install=rpm/postinstall --pre-uninstall=rpm/preuninstall
#
#builddeb:
#	# build the source package in the parent directory
#	# then rename it to project_version.orig.tar.gz
#	$(PYTHON) setup.py sdist $(COMPILE) --dist-dir=../
#	rename -f 's/$(PROJECT)-(.*)\.tar\.gz/$(PROJECT)_$$1\.orig\.tar\.gz/' ../*
#	# build the package
#	dpkg-buildpackage -kjasonrbriggs@gmail.com -i -I -rfakeroot

clean:
ifeq ($(PLATFORM),Linux)
	$(MAKE) -f $(CURDIR)/debian/rules clean
endif
	rm -rf build/ MANIFEST dist/ *.egg-info/ tmp/
	find . -name '*.pyc' -delete

release: updateversion
	poetry publish

docker-image:
	docker build -t stomppy docker/

run-docker:
	docker run --add-host="my.example.com:127.0.0.1" --add-host="my.example.org:127.0.0.1" --add-host="my.example.net:127.0.0.1" -d -p 61613:61613 -p 62613:62613 -p 62614:62614 -p 63613:63613 -p 64613:64613 --name stomppy -it stomppy
	docker ps
	docker exec -it stomppy /bin/sh -c "/etc/init.d/activemq start"
	docker exec -it stomppy /bin/sh -c "/etc/init.d/stompserver start"
	docker exec -it stomppy /bin/sh -c "/etc/init.d/rabbitmq-server start"
	docker exec -it stomppy /bin/sh -c "start-stop-daemon --start --background --exec /usr/sbin/haproxy -- -f /etc/haproxy/haproxy.cfg"
	docker exec -it stomppy /bin/sh -c "testbroker/bin/artemis-service start"

remove-docker:
	docker stop stomppy
	docker rm stomppy
