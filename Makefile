.PHONY: init doctor deploy backup restore ps logs down

init:
	./scripts/init.sh

doctor:
	./scripts/doctor.sh

deploy:
	./scripts/deploy.sh

backup:
	./scripts/backup.sh

restore:
	@test -n "$(BACKUP)" || (echo "usage: make restore BACKUP=backups/TIMESTAMP" && exit 2)
	./scripts/restore.sh "$(BACKUP)"

ps:
	docker compose ps

logs:
	docker compose logs -f web caddy db

down:
	docker compose down
