# Test::Script::AnyEvent [![Build Status](https://secure.travis-ci.org/plicease/Test-Script-AnyEvent.png)](http://travis-ci.org/plicease/Test-Script-AnyEvent) [![Build status](https://ci.appveyor.com/api/projects/status/fcxqxw3utawfhdtr/branch/master?svg=true)](https://ci.appveyor.com/project/plicease/Test-Script-AnyEvent/branch/master)

Non-blocking friendly tests for scripts

# SYNOPSIS

    use Test::Stream -V1;
    use Test::Script::AnyEvent;
    
    plan 1;
    
    script_compiles 'script/myscript.pl';

# DESCRIPTION

This is a non-blocking friendly version of [Test::Script](https://metacpan.org/pod/Test::Script).  It is useful when you have scripts
that you want to test against a [AnyEvent](https://metacpan.org/pod/AnyEvent) based services that are running in the main test
process.

It uses the brand spanking new [Test::Stream](https://metacpan.org/pod/Test::Stream), which means that it is not (as of this writing)
compatible with [Test::More](https://metacpan.org/pod/Test::More) and friends, though hopefully that will be rectified one day.

# FUNCTIONS

## script\_compiles

    script_compiles $scriot;
    script_compiles $script, $test_name;

Tests to see Perl can compile the script.

`$script` should be the path to the script in unix-format non-absolute form.

# AUTHOR

Graham Ollis &lt;plicease@cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Graham Ollis.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
