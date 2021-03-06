#!/bin/bash

export PERL5LIB=$PWD/ensembl-test/modules:$PWD/ensembl/modules:$PWD/ensembl-io/modules::$PWD/lib

export SKIP_TESTS=""

echo "Running test suite"
if [ "$COVERALLS" = 'true' ]; then
  PERL5OPT='-MDevel::Cover=+ignore,bioperl,+ignore,ensembl-test,+ignore,ensembl,+ignore,ensembl-io' perl $PWD/ensembl-test/scripts/runtests.pl -verbose t $SKIP_TESTS
else
  perl $PWD/ensembl-test/scripts/runtests.pl t $SKIP_TESTS
fi

rt=$?
if [ $rt -eq 0 ]; then
  if [ "$COVERALLS" = 'true' ]; then
    echo "Running Devel::Cover coveralls report"
    cover --nosummary -report coveralls
  fi
  exit $?
else
  exit $rt
fi
