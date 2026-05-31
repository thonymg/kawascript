.PHONY: serve test build

## Lance le site de documentation sur http://localhost:8080/v2/index.html#try
serve:
	node scripts/serve.js

## Lance la suite de tests
test:
	node ./bin/cake test

## Compile les sources CoffeeScript
build:
	node ./bin/cake build
