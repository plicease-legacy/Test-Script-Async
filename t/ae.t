use strict;
use warnings;
use Test::Stream '-V1';
use Test::Stream::Plugin::Compare qw( match );
use AE;
use AnyEvent::Socket;
use AnyEvent::Handle;
use Test::Script::Async;

plan 4;

my @w;
push @w, AE::timer 15, 0, sub { diag "timeout!"; exit 2 };

my $port = do {
  my $cv = AE::cv;
  push @w, tcp_server '127.0.0.1', undef, sub {
    my($fh, $host, $port) = @_;

    my $handle = AnyEvent::Handle->new(
      fh => $fh,
    );
    
    $handle->push_write("platypus man\015\012");
    $handle->push_shutdown;
  }, sub { $cv->send($_[2]) };
  $cv->recv;
};

is($port, match qr{^[0-9]+$}, "port = $port");

script_runs(['corpus/aeclient.pl', $port])
  ->exit_is(22)
  ->out_like(qr{platypus man})
  ->diag_if_fail;
