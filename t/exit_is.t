use strict;
use warnings;
use Test::Stream qw( -V1 -Tester );
use Test::Script::Async;

plan 4;

is(
  intercept { script_runs(["corpus/exit.pl", 22])->exit_is(22) },
  array {
    event Ok => sub {
      call pass => T();
    };
    event Ok => sub {
      call pass => T();
      call name => 'script exited with value 22';
    };
    end;
  },
  "exit_is good",
);

is(
  intercept { script_runs(["corpus/exit.pl", 42])->exit_is(22) },
  array {
    event Ok => sub {
      call pass => T();
    };
    event Ok => sub {
      call pass => F();
      call name => 'script exited with value 22';
    };
    event Diag => sub {
      call message => 'script exited with value 42';
    };
    end;
  },
  "exit_is bad",
);

is(
  intercept { script_runs(["corpus/exit.pl", 22])->exit_is(22,'custom name') },
  array {
    event Ok => sub {
      call pass => T();
    };
    event Ok => sub {
      call pass => T();
      call name => 'custom name';
    };
    end;
  },
  "exit_is with custom name"
);

is(
  intercept { script_runs("corpus/bogus.pl")->exit_is(22) },
  array {
    event Ok => sub {
      call pass => F();
    };
    event Diag => sub {};
    event Ok => sub {
      call pass => F();
      call name => 'script exited with value 22';
    };
    event Diag => sub {
      call message => 'script did not run so did not exit';
    };
    end;
  },
  "exit_is with failed script_runs",
);
