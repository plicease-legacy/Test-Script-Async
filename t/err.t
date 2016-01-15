use strict;
use warnings;
use Test::Stream qw( -V1 );
use Test::Script::Async;

plan 2;

my $run = script_runs "corpus/output.pl";

is $run->err, [map { "stderr $_" } qw( one two three four ) ], 'error output matches';
