use strict;
use warnings;
use Test::Script::AnyEvent;
use Test::Stream -V1;

skip_all 'because it will always fail';
plan 1;

script_compiles 'corpus/bad.pl';
script_compiles 'corpus/bogus.pl';
