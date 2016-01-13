use strict;
use warnings;
use Test::Stream qw( -V1 -Tester );
use Test::Script::AnyEvent;

plan 3;

is(
  intercept { script_compiles "corpus/good.pl" },
  array {
    event Ok => sub {
      call pass => T();
      call name => 'Script corpus/good.pl compiles';
    };
    end;
  },
  "compiles good without test name",
);


is(
  intercept { script_compiles "corpus/bad.pl" },
  array {
    event Ok => sub {
      call pass => F();
      call name => 'Script corpus/bad.pl compiles';
    };
    event Diag => sub {
    };
    event Diag => sub {
      call message => 'exit - 255';
    };
    end;
  },
  "compiles bad without test name",
);

is(
  intercept { script_compiles "corpus/bogus.pl" },
  array {
    event Ok => sub {
      call pass => F();
      call name => 'Script corpus/bogus.pl compiles';
    };
    event Diag => sub {
    };
    event Diag => sub {
      call message => 'exit - 2';
    };
    end;
  },
  "compiles bad without test name",
);
