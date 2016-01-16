# Test::Script::Async [![Build Status](https://secure.travis-ci.org/plicease/Test-Script-Async.png)](http://travis-ci.org/plicease/Test-Script-Async) [![Build status](https://ci.appveyor.com/api/projects/status/fcxqxw3utawfhdtr/branch/master?svg=true)](https://ci.appveyor.com/project/plicease/Test-Script-Async/branch/master)

Non-blocking friendly tests for scripts

# SYNOPSIS

    use Test::Stream -V1;
    use Test::Script::Async;
    
    plan 4;
    
    # test that the scripts compiles.
    script_compiles 'script/myscript.pl';
    
    # test that we are able to run the script
    script_runs('script/myscript.pl')
      # and it exits with a success value
      ->exit_is(0)
      # and that the standard output has
      # foo in it somewhere
      ->out_like(qr{foo})
      # print diagnostic if any of the tests
      # for this run failed.  Useful for
      # cpan testers reports
      ->diag_if_fail;

# DESCRIPTION

This is a non-blocking friendly version of [Test::Script](https://metacpan.org/pod/Test::Script).  It is useful when you have scripts
that you want to test against a [AnyEvent](https://metacpan.org/pod/AnyEvent) or [Mojolicious](https://metacpan.org/pod/Mojolicious) based services that are running
in the main test process.

The interface is a little different for running scripts, in that instead of specifying a number
of attributes that should be true as an argument, the ["script\_runs"](#script_runs) function returns an
instance of [Test::Script::Async](https://metacpan.org/pod/Test::Script::Async) that can then be interrogated for things like exit value
and output.

It uses the brand spanking new [Test::Stream](https://metacpan.org/pod/Test::Stream), which means that it is not (as of this writing)
compatible with [Test::More](https://metacpan.org/pod/Test::More) and friends, though hopefully that will be rectified one day.

# FUNCTIONS

## script\_compiles

    script_compiles $scriot;
    script_compiles $script, $test_name;

Tests to see Perl can compile the script.

`$script` should be the path to the script in unix-format non-absolute form.

## script\_runs

    my $run = script_runs $script;
    my $run = script_runs $script, $test_name;
    my $run = script_runs [ $script, @arguments ];
    my $run = script_runs [ $script, @arguments ], $test_name;

Attempt to run the given script.  The only test made on this call
is simply that the script ran.  The reasons this test might fail
are: the script does not exist, or the operating system is unable
to execute perl to run the script.  The returned `$run` object
(an instance of [Test::Script::Async](https://metacpan.org/pod/Test::Script::Async)) can be used to further
test the success or failure of the script run. 

Note that this test does NOT fail on compile error, for that
use ["script\_compiles"](#script_compiles).

# ATTRIBUTES

## out

    my $listref = $run->out;

Returns a list reference of the captured standard output, split on new lines.

## err

    my $listref = $run->err;

Returns a list reference of the captured standard error, split on new lines.

## exit

    my $int = $run->exit;

Returns the exit value of the script run.

## signal

    my $int = $run->signal;

Returns the signal that killed the script, if any.  It will be 0 if the script
exited normally.

# METHODS

## exit\_is

    $run->exit_is($value);
    $run->exit_is($value, $test_name);

Test passes if the script run exited with the given value.

## exit\_isnt

    $run->exit_isnt($value);
    $run->exit_isnt($value, $test_name);

Same as ["exit\_is"](#exit_is) except the test fails if the exit value matches.

## signal\_is

    $run->signal_is($value);
    $run->signal_is($value, $test_name);

Test passes if the script run was killed by the given signal.

Note that this is inherently unportable!  Especially on Windows!

## signal\_isnt

    $run->signal_isnt($value);
    $run->signal_isnt($value, $test_name);

Same as ["signal\_is"](#signal_is) except the test fails if the exit value matches.

## out\_like

    $run->out_like($regex);
    $run->out_like($regex, $test_name);

Test passes if one of the output lines matches the given regex.

## out\_unlike

    $run->out_like($regex);
    $run->out_like($regex, $test_name);

Test passes if none of the output lines matches the given regex.

## err\_like

    $run->out_like($regex);
    $run->out_like($regex, $test_name);

Test passes if one of the standard error output lines matches the given regex.

## err\_unlike

    $run->err_like($regex);
    $run->err_like($regex, $test_name);

Test passes if none of the standard error output lines matches the given regex.

## diag

    $run->diag;

Print out diagnostics (with `diag`) to describe the run of the script.
This includes the script filename, any arguments, the termination status
(either error, exit value or signal number), the output and the standard
error output.

## note

    $run->note;

Same as ["diag"](#diag) above, but use `note` instead of `diag` to print out
the diagnostic.

## diag\_if\_fail

    $run->diag_if_fail;

Print out full diagnostic using ["diag"](#diag) if any of the tests for this run
failed.  This can be handy after a long series of tests for cpan testers.
If everything is good then no diagnostic is printed but if anything failed,
then you will see the script, arguments, termination status and output.

# AUTHOR

Graham Ollis &lt;plicease@cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Graham Ollis.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
