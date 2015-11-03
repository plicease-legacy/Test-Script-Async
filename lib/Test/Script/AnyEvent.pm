package Test::Script::AnyEvent;

use strict;
use warnings;
use 5.010;
use Carp ();
use AE;
use AnyEvent::Open3::Simple;
use File::Spec ();
use Probe::Perl;
use Test::Stream::Context qw( context );
use Test::Stream::Exporter;
default_exports qw( script_compiles );
no Test::Stream::Exporter;

# ABSTRACT: Non-blocking friendly tests for scripts
# VERSION

=head1 SYNOPSIS

 use Test::Stream -V1;
 use Test::Script::AnyEvent;
 
 plan 1;
 
 script_compiles 'script/myscript.pl';

=head1 DESCRIPTION

This is a non-blocking friendly version of L<Test::Script>.  It is useful when you have scripts
that you want to test against a L<AnyEvent> based services that are running in the main test
process.

It uses the brand spanking new L<Test::Stream>, which means that it is not (as of this writing)
compatible with L<Test::More> and friends, though hopefully that will be rectified one day.

=cut

sub _path ($)
{
  my $path = shift;
  Carp::croak("Did not provide a script name") unless $path;
  Carp::croak("Script name must be relative") if File::Spec::Unix->file_name_is_absolute($path);
  File::Spec->catfile(
    File::Spec->curdir,
    split /\//, $path
  );
}

sub _perl ()
{
  state $perl;
  $perl //= Probe::Perl->find_perl_interpreter;
}

=head1 FUNCTIONS

=head2 script_compiles

 script_compiles $scriot;
 script_compiles $script, $test_name;

Tests to see Perl can compile the script.

C<$script> should be the path to the script in unix-format non-absolute form.

=cut

sub script_compiles
{
  my($script, $test_name) = @_;
  #my @args;
  #($script, @args) = @$script if ref $script eq 'ARRAY';
  my @libs = map { "-I$_" } grep { !ref($_) } @INC;
  #my @cmd = ( _perl, @libs, '-c', _path $script, @args );
  my @cmd = ( _perl, @libs, '-c', _path $script );
  
  $test_name ||= "Script $script compiles";
  
  my $done = AE::cv;
  my @stderr;

  my $ipc = AnyEvent::Open3::Simple->new(
    on_stderr => sub {
      my($proc, $line) = @_;
      push @stderr, $line;
    },
    on_exit   => sub {
      my($proc, $exit, $sig) = @_;
      
      my $ok = $exit == 0 && $sig == 0 && grep / syntax OK$/, @stderr;
      
      my $ctx = context();
      $ctx->ok($ok, $test_name);
      $ctx->diag(@stderr) unless $ok;
      $ctx->diag("exit - $exit") if $exit;
      $ctx->diag("signal - $sig") if $sig;
      $ctx->release;
      
      $done->send($ok);
      
    },
    on_error  => sub {
      my($error) = @_;
      
      my $ctx = context();
      $ctx->ok(0, $test_name);
      $ctx->diag("error compiling script: $error");
      $ctx->release;
      
      $done->send(0);
    },
  );
  
  $ipc->run(@cmd);
  
  $done->recv;
}

1;
