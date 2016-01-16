use strict;
use warnings;
BEGIN { $ENV{MOJO_REACTOR} = 'Mojo::Reactor::Poll'; $ENV{DEVEL_HIDE_VERBOSE} = 0 }
use Test::Stream SkipWithout => ['Devel::Hide'];
use Devel::Hide 'EV';
use Test::Stream '-V1', SkipWithout => [{ Mojolicious => 6.02  }], Classic => [qw( isnt )];
use Mojo::IOLoop;
use Mojo::Reactor;
use Mojolicious::Lite;
use Test::Script::Async;

plan 1;

get '/foo' => sub {
  my($c) = @_;
  $c->render(text => 'Platypus Man');
};

isnt(Mojo::Reactor->detect, 'Mojo::Reactor::EV', "Mojo::Reactor->detect = @{[ Mojo::Reactor->detect ]}");

#ok !$INC{'AnyEvent.pm'}, 'did not load AnyEvent';
#diag "AnyEvent.pm = $INC{'AnyEvent.pm'}" if $INC{'AnyEvent.pm'};

