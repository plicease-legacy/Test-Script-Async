use strict;
use warnings;
use Test::Script::AnyEvent;
use Test::Stream -V1;

plan 1;

script_compiles 'corpus/good.pl';
