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

Note that this test does NOT fail on compile error, for that
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

=head1 METHODS

=head2 exit_is

 $run->exit_is($value);
 $run->exit_is($value, $test_name);

Test passes if the script run exited with the given value.

=cut

our $reverse = 0;
our $level   = 0;

sub exit_is
{
  my($self, $value, $test_message) = @_;
  my $ctx = context( level => $level );

  $test_message ||= $reverse ? "script exited with a value other than $value" : "script exited with value $value";
  my $ok = defined $self->exit && !$self->{signal} && ($reverse ? $self->exit != $value : $self->exit == $value);

  $ctx->ok($ok, $test_message);
  if(!defined $self->exit)
  {
    $ctx->diag("script did not run so did not exit");
  }
  elsif($self->signal)
  {
    $ctx->diag("script killed with signal @{[ $self->signal ]}");
  }
  elsif(!$ok)
  {
    $ctx->diag("script exited with value @{[ $self->exit ]}");
  }

  $ctx->release;
  $self;
}

=head2 exit_isnt

 $run->exit_isnt($value);
 $run->exit_isnt($value, $test_name);

Same as L</exit_is> except the test fails if the exit value matches.

=cut

sub exit_isnt
{
  local $reverse = 1;
  local $level   = 1;
  shift->exit_is(@_);
}

=head2 signal_is

 $run->signal_is($value);
 $run->signal_is($value, $test_name);

Test passes if the script run was killed by the given signal.

Note that this is inherently unportable!  Especially on Windows!

=cut

sub signal_is
{
  my($self, $value, $test_message) = @_;
  my $ctx = context(level => $level);

  $test_message ||= $reverse ? "script not killed by signal $value" : "script killed by signal $value";
  my $ok = $self->signal && ($reverse ? $self->signal != $value : $self->signal == $value);

  $ctx->ok($ok, $test_message);
  if(!defined $self->signal)
  {
    $ctx->diag("script did not run so was not killed");
  }
  elsif(!$self->signal)
  {
    $ctx->diag("script exited with value @{[ $self->exit ]}");
  }
  elsif(!$ok)
  {
    $ctx->diag("script killed with signal @{[ $self->signal ]}");
  }

  $ctx->release;
  $self;
}

=head2 signal_isnt

 $run->signal_isnt($value);
 $run->signal_isnt($value, $test_name);

Same as L</signal_is> except the test fails if the exit value matches.

=cut

sub signal_isnt
{
  local $reverse = 1;
  local $level   = 1;
  shift->signal_is(@_);
}

=head2 out_like

 $run->out_like($regex);
 $run->out_like($regex, $test_name);

Test passes if one of the output lines matches the given regex.

=cut

our $stream = 'out';
our $stream_name = 'standard output';

sub out_like
{
  my($self, $regex, $test_name) = @_;
  
  my $ctx = context(level => $level);
  $test_name ||= $reverse ? "$stream_name does not match $regex" : "$stream_name matches $regex";
  
  my $ok;
  my @diag;
  
  if($reverse)
  {
    $ok = 1;
    my $num = 1;
    foreach my $line (@{ $self->{$stream} })
    {
      if($line =~ $regex)
      {
        $ok = 0;
        push @diag, "line $num of $stream_name matches: $line";
      }
      $num++;
    }
  }
  else
  {
    $ok = 0;
    foreach my $line (@{ $self->{$stream} })
    {
      if($line =~ $regex)
      {
        $ok = 1;
        last;
      }
    }
  }
  
  $ctx->ok($ok, $test_name);
  $ctx->diag($_) for @diag;
  
  $ctx->release;
  
  $self;
}

=head2 out_unlike

 $run->out_like($regex);
 $run->out_like($regex, $test_name);

Test passes if none of the output lines matches the given regex.

=cut

sub out_unlike
{
  local $reverse = 1;
  local $level   = 1;
  shift->out_like(@_);
}

=head2 err_like

 $run->out_like($regex);
 $run->out_like($regex, $test_name);

Test passes if one of the standard error output lines matches the given regex.

=cut

sub err_like
{
  local $stream      = 'err';
  local $stream_name = 'standard error';
  local $level       = 1;
  shift->out_like(@_);
}

=head2 err_unlike

 $run->err_like($regex);
 $run->err_like($regex, $test_name);

Test passes if none of the standard error output lines matches the given regex.

=cut

sub err_unlike
{
  local $stream      = 'err';
  local $stream_name = 'standard error';
  local $reverse     = 1;
  local $level       = 1;
  shift->out_like(@_);
}

1;

