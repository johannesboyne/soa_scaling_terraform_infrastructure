.PHONY: build

build: buildgo builddocker

buildgo:
	CGO_ENABLED=0 GOOS=linux go build -ldflags "-s" -a -installsuffix cgo -o main 

builddocker:
	docker build -t johannesboyne/webexample .

run:
	docker run -p "1337:1337" -e "PORT=1337" webexample

runapi:
	docker run -p "1337:1337" -e "PORT=1337" -e "SERVICE=api" johannesboyne/webexample

rundb:
	docker run -p "1337:1337" -e "PORT=1337" -e "SERVICE=db" johannesboyne/webexample

runslackbot:
	docker run -p "1337:1337" -e "PORT=1337" -e "SERVICE=slackbot" johannesboyne/webexample
