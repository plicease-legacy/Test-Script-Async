package Test::Script::Async;

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
default_exports qw( script_compiles script_runs );
no Test::Stream::Exporter;

# ABSTRACT: Non-blocking friendly tests for scripts
# VERSION

=head1 SYNOPSIS

 use Test::Stream -V1;
 use Test::Script::Async;
 
 plan 1;
 
 script_compiles 'script/myscript.pl';

=head1 DESCRIPTION

This is a non-blocking friendly version of L<Test::Script>.  It is useful when you have scripts
that you want to test against a L<AnyEvent> based services that are running in the main test
process.

The interface is a little different for running scripts, in that instead of specifying a number
of attributes that should be true as an argument, the L</script_runs> function returns an
instance of L<Test::Script::Async> that can then be interrogated for things like exit value
and output.

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

  my $ctx = context();

  my $ipc = AnyEvent::Open3::Simple->new(
    on_stderr => sub {
      my($proc, $line) = @_;
      push @stderr, $line;
    },
    on_exit   => sub {
      my($proc, $exit, $sig) = @_;
      
      my $ok = $exit == 0 && $sig == 0 && grep / syntax OK$/, @stderr;
      
      $ctx->ok($ok, $test_name);
      $ctx->diag(@stderr) unless $ok;
      $ctx->diag("exit - $exit") if $exit;
      $ctx->diag("signal - $sig") if $sig;
      
      $done->send($ok);
      
    },
    on_error  => sub {
      my($error) = @_;
      
      $ctx->ok(0, $test_name);
      $ctx->diag("error compiling script: $error");
      
      $done->send(0);
    },
  );
  
  $ipc->run(@cmd);
  my $ok = $done->recv;
  $ctx->release;
  
  $ok;
}

=head2 script_runs

 my $run = script_runs $script;
 my $run = script_runs $script, $test_name;
 my $run = script_runs [ $script, @arguments ];
 my $run = script_runs [ $script, @arguments ], $test_name;

Attempt to run the given script.  The only test made on this call
is simply that the script ran.  The reasons this test might fail
are: the script does not exist, or the operating system is unable
to execute perl to run the script.  The returned C<$run> object
(an instance of L<Test::Script::Async>) can be used to further
test the success or failure of the script run. 

Note that this test does NOT fail on compolation error, for that
use L</script_compiles>.

=cut

# TODO: support stdin input

sub script_runs
{
  my($script, $test_name) = @_;
  my @libs = map { "-I$_" } grep { !ref($_) } @INC;
  $script = [ $script ] unless ref $script;
  my @args;
  ($script, @args) = @$script;
  my @cmd = ( _perl, @libs, _path $script, @args );
  
  $test_name ||= @args ? "Script $script runs with arguments @args" : "Script $script runs";
  
  my $done = AE::cv;
  my $run = bless { out => [], err => [], ok => 0 }, __PACKAGE__;
  my $ctx = context();

  unless(-f $script)
  {
    $ctx->ok(0, $test_name);
    $ctx->diag("script does not exist");
    $ctx->release;
    return $run;
  }

  my $ipc = AnyEvent::Open3::Simple->new(
    on_stderr => sub {
      my(undef, $line) = @_;
      push @{ $run->{err} }, $line;
    },
    on_stdout => sub {
      my(undef, $line) = @_;
      push @{ $run->{out} }, $line;
    },
    on_exit   => sub {
      (undef, $run->{exit}, $run->{signal}) = @_;

      $run->{ok} = 1;
      $ctx->ok(1, $test_name);
      $done->send;
      
    },
    on_error  => sub {
      my($error) = @_;
      
      $run->{ok} = 0;
      $ctx->ok(0, $test_name);
      $ctx->diag("error running script: $error");      
      $done->send;
    },
  );
  
  $ipc->run(@cmd);
  $done->recv;
  $ctx->release;
  
  $run;
}

=head1 ATTRIBUTES

=head2 out

 my $listref = $run->out;

Returns a list reference of the captured standard output, split on new lines.

=head2 err

 my $listref = $run->err;

Returns a list reference of the captured standard error, split on new lines.

=head2 exit

 my $int = $run->exit;

Returns the exit value of the script run.

=head2 signal

 my $int = $run->signal;

Returns the signal that killed the script, if any.  It will be 0 if the script
exited normally.

=cut

sub out { shift->{out} }
sub err { shift->{err} }
sub exit { shift->{exit} }
sub signal { shift->{signal} }

1;

