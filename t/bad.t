use strict;
use warnings;
use Test::Script::Async;
use Test::Stream -V1;

skip_all 'because it will always fail';
plan 5;

script_compiles 'corpus/bad.pl';
script_compiles 'corpus/bogus.pl';

script_runs('corpus/good.pl')
  ->exit_is(22)
  ->exit_isnt(0);

