# Python MTProxy Makefile

.PHONY: help install test lint clean deploy start stop restart status logs

# Default target
help:
	@echo "Available commands:"
	@echo "  install     - Install dependencies and setup virtual environment"
	@echo "  test        - Run tests"
	@echo "  lint        - Run code linting"
	@echo "  clean       - Clean temporary files"
	@echo "  deploy      - Deploy to remote server (requires HOST variable)"
	@echo "  start       - Start service locally or remotely"
	@echo "  stop        - Stop service locally or remotely" 
	@echo "  restart     - Restart service locally or remotely"
	@echo "  status      - Check service status locally or remotely"
	@echo "  logs        - View logs locally or remotely"
	@echo ""
	@echo "Remote examples:"
	@echo "  make deploy HOST=user@server"
	@echo "  make status HOST=user@server"
	@echo "  make logs HOST=user@server"

# Local development
install:
	python3 -m pip install --upgrade pip
	python3 -m pip install -r requirements.txt
	python3 -m pip install -r requirements-dev.txt
	python3 -m pip install -e .

test:
	python3 -m pytest tests/ -v --cov=mtproxy

lint:
	python3 -m flake8 mtproxy/ tools/ tests/
	python3 -m black --check mtproxy/ tools/ tests/
	python3 -m isort --check-only mtproxy/ tools/ tests/

format:
	python3 -m black mtproxy/ tools/ tests/
	python3 -m isort mtproxy/ tools/ tests/

clean:
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
	find . -type f -name "*.pyo" -delete
	find . -type f -name "*.pyd" -delete
	find . -type f -name ".coverage" -delete
	find . -type d -name "*.egg-info" -exec rm -rf {} +
	rm -rf build/ dist/ .pytest_cache/ .coverage htmlcov/

# Local service management
start:
ifdef HOST
	ssh $(HOST) "cd /opt/python-mtproxy && python3 tools/mtproxy_cli.py start"
else
	python3 tools/mtproxy_cli.py start
endif

stop:
ifdef HOST
	ssh $(HOST) "cd /opt/python-mtproxy && python3 tools/mtproxy_cli.py stop"
else
	python3 tools/mtproxy_cli.py stop
endif

restart:
ifdef HOST
	ssh $(HOST) "cd /opt/python-mtproxy && python3 tools/mtproxy_cli.py restart"
else
	python3 tools/mtproxy_cli.py restart
endif

status:
ifdef HOST
	ssh $(HOST) "cd /opt/python-mtproxy && python3 tools/mtproxy_cli.py status"
else
	python3 tools/mtproxy_cli.py status
endif

logs:
ifdef HOST
	ssh $(HOST) "cd /opt/python-mtproxy && python3 tools/log_viewer.py --follow"
else
	python3 tools/log_viewer.py --follow
endif

# Remote deployment
deploy:
ifndef HOST
	$(error HOST is required. Usage: make deploy HOST=user@server)
endif
	@echo "Deploying to $(HOST)..."
	rsync -avz --exclude='.git' --exclude='__pycache__' --exclude='*.pyc' ./ $(HOST):/tmp/python-mtproxy/
	ssh $(HOST) "sudo bash /tmp/python-mtproxy/scripts/deploy.sh --production"

# Health check
health:
ifdef HOST
	ssh $(HOST) "cd /opt/python-mtproxy && python3 tools/health_check.py"
else
	python3 tools/health_check.py
endif

# Update
update:
ifdef HOST
	ssh $(HOST) "cd /opt/python-mtproxy && python3 tools/mtproxy_cli.py update --apply"
else
	python3 tools/mtproxy_cli.py update --apply
endif
