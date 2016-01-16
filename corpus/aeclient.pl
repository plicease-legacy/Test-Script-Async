use strict;
use warnings;
use AnyEvent;
use AnyEvent::Socket;
use AnyEvent::Handle;

my($port) = @ARGV;

my @w;
push @w, AnyEvent->timer(after => 10, cb=> sub { warn "timeout!"; exit 2 });

my $cv = AnyEvent->condvar;

tcp_connect '127.0.0.1', $port, sub {
  my($fh) = @_;

  my $handle = AnyEvent::Handle->new(
    fh => $fh,
  );

  $handle->on_read(sub {
    $handle->push_read( line => sub {
      my($handle, $line) = @_;
      print "$line\n";
      $cv->send(22);
    });
  });

};

exit $cv->recv;
