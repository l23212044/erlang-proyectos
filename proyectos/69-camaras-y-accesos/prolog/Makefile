.PHONY: test run demo clean

test:
	swipl -q -g "consult('test/run_tests.pl'),run_tests,halt"

run:
	./scripts/run.sh

demo:
	./scripts/demo.sh --limpiar

clean:
	rm -rf data
