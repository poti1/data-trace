#!/usr/bin/env perl

use 5.006;
use strict;
use warnings;
use Test::More;
use Data::Trace;
use feature qw( say );
use Data::Dumper qw( Dumper );
use Storable;

pass "data-trace start";

sub run {
    my ($code,$expect_return) = @_;
    $expect_return //= 1;
    my $output = "";
    my @return;

    {
        local *STDOUT;
        local *STDERR;
        open STDOUT, ">",  \$output or die $!;
        open STDERR, ">>", \$output or die $!;

        # Test effects of wantarray.
        if ( $expect_return ) {
            @return = eval { $code->() };
        }
        else {
            eval { $code->() };
        }
    }

    chomp $output;

    ($output,@return);
}

my $test_scalar;
my @test_array;
my %test_hash;
my $clone;

sub reset_vars {
    $test_scalar = 'test_scalar';
    @test_array  = ( 'test', 'array' );
    %test_hash   = ( test => 'hash' );
    undef $clone;
}

###########################################
#               Cases
###########################################

my $single_line_trace = qr{ ^ HERE: \s+ main:: .+ $ }x;
my $multi_line_trace  = qr{
    ^
    \n HERE: \s+ main:: .+
    \n \s+ \|- \s+ main::run\b .+
    $
}x;
my $single_line_store = qr{ ^ STORE\( \s* "updated_test_scalar" \s* \): .+ $ }x;
my $multi_line_store = qr{
    ^
    \n STORE\( \s* "updated_test_scalar" \s* \): .+
    \n \s+ \|- \s+ main::__ANON__\b .+
    \n \s+ \|- \s+ main::__ANON__\b .+
    $
}x;
my $clone_multi_store = qr{
    ^
    \n STORE\( \s* "cloned_var" \s* \): .+
    \n \s+ \|- \s+ main::__ANON__\b .+
    \n \s+ \|- \s+ main::__ANON__\b .+
    \n
    \n STORE\( \s* "updated_test_scalar2" \s* \): .+
    \n \s+ \|- \s+ main::__ANON__\b .+
    \n \s+ \|- \s+ main::__ANON__\b .+
    $
}x;

# Only stack trace.
sub _define_cases_stack_trace {
    (
        {
            name     => "no input",
            trace_only => 1,
            args     => [],
            expected => {
                stdout => $single_line_trace,
            },
        },
        {
            name     => "args: 1",
            trace_only => 1,
            args     => [ 1 ],
            expected => {
                stdout => $single_line_trace,
            },
        },
        {
            name     => "args: -levels 1",
            trace_only => 1,
            args     => [ -levels => 1 ],
            expected => {
                stdout => $single_line_trace,
            },
        },
        {
            name     => "args: 2",
            trace_only => 1,
            args     => [ 2 ],
            expected => {
                stdout => $multi_line_trace,
            },
        },
        {
            name     => "args: -levels 2",
            trace_only => 1,
            args     => [ -levels => 2 ],
            expected => {
                stdout => $multi_line_trace,
            },
        },
    )
}

# Scalar
sub _define_cases_scalar_basic {
    (
        {
            name => "scalar",
            args => [
                \$test_scalar,
            ],
            actions => sub {
                $test_scalar = 'updated_test_scalar';
            },
            expected => {
                stdout   => $multi_line_store,
                variable => \$test_scalar,
                value    => \"updated_test_scalar",
            },
        },
        {
            name => "scalar -var",
            args => [
                -var => \$test_scalar,
            ],
            actions => sub {
                $test_scalar = 'updated_test_scalar';
            },
            expected => {
                stdout   => $multi_line_store,
                variable => \$test_scalar,
                value    => \"updated_test_scalar",
            },
        },
        {
            name => "scalar 1",
            args => [
                \$test_scalar,
                1,
            ],
            actions => sub {
                $test_scalar = 'updated_test_scalar';
            },
            expected => {
                stdout   => $single_line_store,
                variable => \$test_scalar,
                value    => \"updated_test_scalar",
            },
        },
        {
            name => "scalar -levels 1",
            args => [
                \$test_scalar,
                -levels => 1,
            ],
            actions => sub {
                $test_scalar = 'updated_test_scalar';
            },
            expected => {
                stdout   => $single_line_store,
                variable => \$test_scalar,
                value    => \"updated_test_scalar",
            },
        },
        {
            name => "scalar -levels 1 -var",
            args => [
                -var    => \$test_scalar,
                -levels => 1,
            ],
            actions => sub {
                $test_scalar = 'updated_test_scalar';
            },
            expected => {
                stdout   => $single_line_store,
                variable => \$test_scalar,
                value    => \"updated_test_scalar",
            },
        },
    )
}

sub _define_cases_scalar_clone {
    (
        {
            name => "scalar clone",
            args => [
                \$test_scalar,
            ],
            actions => sub {
                $clone       = Storable::dclone( \$test_scalar );
                $$clone      = "cloned_var";
                $test_scalar = 'updated_test_scalar2';
            },
            expected => {
                stdout   => $clone_multi_store,
                variable => \$test_scalar,
                value    => \"updated_test_scalar2",
                clone    => \"cloned_var",
            },
        },
        {
            name => "scalar clone -var",
            args => [
                -var => \$test_scalar,
            ],
            actions => sub {
                $test_scalar = 'updated_test_scalar';
            },
            expected => {
                stdout   => $multi_line_store,
                variable => \$test_scalar,
                value    => \"updated_test_scalar",
            },
        },
        {
            name => "scalar clone 1",
            args => [
                \$test_scalar,
                1,
            ],
            actions => sub {
                $test_scalar = 'updated_test_scalar';
            },
            expected => {
                stdout   => $single_line_store,
                variable => \$test_scalar,
                value    => \"updated_test_scalar",
            },
        },
        {
            name => "scalar clone -levels 1",
            args => [
                \$test_scalar,
                -levels => 1,
            ],
            actions => sub {
                $test_scalar = 'updated_test_scalar';
            },
            expected => {
                stdout   => $single_line_store,
                variable => \$test_scalar,
                value    => \"updated_test_scalar",
            },
        },
        {
            name => "scalar clone -levels 1 -var",
            args => [
                -var    => \$test_scalar,
                -levels => 1,
            ],
            actions => sub {
                $test_scalar = 'updated_test_scalar';
            },
            expected => {
                stdout   => $single_line_store,
                variable => \$test_scalar,
                value    => \"updated_test_scalar",
            },
        },
    )
}

sub _define_cases_scalar_clone_old {
    (
        {
            name => "scalar with clone",
            args => {
                -variable => \$test_scalar,
            },
            actions => sub {
                $clone       = Storable::dclone( \$test_scalar );
                $$clone      = "cloned_test_scalar";
                $test_scalar = 'updated_test_scalar2';
            },
            expected => {
                watch_obj => 1,
                stdout    => "",
                value     => \"updated_test_scalar2",
                clone     => \"cloned_test_scalar",
            },
        },
        {
            name => "scalar with clone - fetch",
            args => {
                -variable => \$test_scalar,
                -fetch    => sub { 42 },
            },
            actions => sub {
                $clone       = Storable::dclone( \$test_scalar );
                $$clone      = $$clone;
                $test_scalar = $test_scalar;
            },
            expected => {
                watch_obj => 1,
                stdout    => "",
                value     => \"42",
                clone     => \"42",
            },
        },
        {
            name => "scalar with clone - store",
            args => {
                -variable => \$test_scalar,
                -store    => sub { shift->Store( 43 ) },
            },
            actions => sub {
                $clone  = Storable::dclone( \$test_scalar );
                $$clone = "new clone value",
                  $test_scalar = "updated_test_scalar";
            },
            expected => {
                watch_obj => 1,
                stdout    => "",
                value     => \"43",
                clone     => \"43",
            },
        },
    )
}

sub _define_cases_scalar_no_clone {
    (
        {
            name => "scalar no clone",
            args => {
                -variable => \$test_scalar,
                -clone    => 0,
            },
            actions => sub {
                $clone       = Storable::dclone( \$test_scalar );
                $$clone      = "cloned_test_scalar";
                $test_scalar = 'updated_test_scalar2';
            },
            expected => {
                watch_obj => 1,
                stdout    => "",
                value     => \"updated_test_scalar2",
                clone     => \"cloned_test_scalar",
            },
        },
        {
            name => "scalar no clone - fetch",
            args => {
                -variable => \$test_scalar,
                -fetch    => sub { 42 },
                -clone    => 0,
            },
            actions => sub {
                $clone       = Storable::dclone( \$test_scalar );
                $$clone      = $$clone;
                $test_scalar = $test_scalar;
            },
            expected => {
                watch_obj => 1,
                stdout    => "",
                value     => \"42",
                clone     => \"test_scalar",
            },
        },
        {
            name => "scalar no clone - store",
            args => {
                -variable => \$test_scalar,
                -store    => sub { shift->Store( 43 ) },
                -clone    => 0,
            },
            actions => sub {
                $clone  = Storable::dclone( \$test_scalar );
                $$clone = "new clone value",
                  $test_scalar = "updated_test_scalar";
            },
            expected => {
                watch_obj => 1,
                stdout    => "",
                value     => \"43",
                clone     => \"new clone value",
            },
        },
    )
}

# Array
sub _define_cases_array_basic {
    (
        {
            name => "array",
            args => {
                -variable => \@test_array,
            },
            actions => sub {
                $test_array[0] = "test2";
            },
            expected => {
                watch_obj => 1,
                stdout    => "",
                value     => [qw( test2 array )],
            },
        },
        {
            name => "array - fetch",
            args => {
                -variable => \@test_array,
                -fetch    => sub { 42 },
            },
            actions => sub {
                $clone = $test_array[0];
            },
            expected => {
                watch_obj => 1,
                stdout    => "",
                value     => [qw( 42 42 )],
                clone     => "42"
            },
        },
        {
            name => "array - store",
            args => {
                -variable => \@test_array,
                -store    => sub { shift->Store( shift, 43 ) },
            },
            actions => sub {
                $test_array[0] = 'updated_test_array';
            },
            expected => {
                watch_obj => 1,
                stdout    => "",
                value     => [qw( 43 array )],
            },
        },
    )
}

sub _define_cases_array_clone {
    (
        {
            name => "array with clone",
            args => {
                -variable => \@test_array,
            },
            actions => sub {
                $clone         = Storable::dclone( \@test_array );
                $test_array[0] = "test3";
                $clone->[0]    = "cloned";
            },
            expected => {
                watch_obj => 1,
                stdout    => "",
                value     => [qw( test3 array )],
                clone     => [qw( cloned array )],
            },
        },
        {
            name => "array with clone - fetch",
            args => {
                -variable => \@test_array,
                -fetch    => sub { 42 },
            },
            actions => sub {
                $clone         = Storable::dclone( \@test_array );
                $test_array[0] = "test3";
                $clone->[0]    = "cloned";
            },
            expected => {
                watch_obj => 1,
                stdout    => "",
                value     => [qw( 42 42 )],
                clone     => [qw( 42 42 )],
            },
        },
        {
            name => "array with clone - store",
            args => {
                -variable => \@test_array,
                -store    => sub { shift->Store( shift, 43 ) },
            },
            actions => sub {
                $clone         = Storable::dclone( \@test_array );
                $test_array[0] = "test3";
                $clone->[1]    = "cloned";
            },
            expected => {
                watch_obj => 1,
                stdout    => "",
                value     => [qw( 43 array )],
                clone     => [qw( test 43 )],
            },
        },
    )
}

sub _define_cases_array_no_clone {
    (
        {
            name => "array no clone",
            args => {
                -variable => \@test_array,
                -clone    => 0,
            },
            actions => sub {
                $clone         = Storable::dclone( \@test_array );
                $test_array[0] = "test4";
                $clone->[0]    = "cloned";
            },
            expected => {
                watch_obj => 1,
                stdout    => "",
                value     => [qw( test4 array )],
                clone     => [qw( cloned array )],
            },
        },
        {
            name => "array no clone - fetch",
            args => {
                -variable => \@test_array,
                -fetch    => sub { 42 },
                -clone    => 0,
            },
            actions => sub {
                $clone         = Storable::dclone( \@test_array );
                $test_array[0] = "test3";
                $clone->[0]    = "cloned";
            },
            expected => {
                watch_obj => 1,
                stdout    => "",
                value     => [qw( 42 42 )],
                clone     => [qw( cloned array )],
            },
        },
        {
            name => "array no clone - store",
            args => {
                -variable => \@test_array,
                -store    => sub { shift->Store( shift, 43 ) },
                -clone    => 0,
            },
            actions => sub {
                $clone         = Storable::dclone( \@test_array );
                $test_array[0] = "test3";
                $clone->[0]    = "cloned";
            },
            expected => {
                watch_obj => 1,
                stdout    => "",
                value     => [qw( 43 array )],
                clone     => [qw( cloned array )],
            },
        },
    )
}

# Hash
sub _define_cases_hash_basic {
    (
        {
            name => "hash",
            args => {
                -variable => \%test_hash,
            },
            actions => sub {
                $test_hash{var} = 'updated_test_hash';
            },
            expected => {
                watch_obj => 1,
                stdout    => "",
                value     => {qw( test hash var updated_test_hash )},
            },
        },
        {
            name => "hash - fetch",
            args => {
                -variable => \%test_hash,
                -fetch    => sub { 42 },
            },
            actions => sub {
                $clone = $test_hash{test};
            },
            expected => {
                watch_obj => 1,
                stdout    => "",
                value     => {qw( test 42 )},
                clone     => "42",
            },
        },
        {
            name => "hash - store",
            args => {
                -variable => \%test_hash,
                -store    => sub { shift->Store( shift, 43 ) },
            },
            actions => sub {
                $test_hash{var} = 'updated_test_hash';
            },
            expected => {
                watch_obj => 1,
                stdout    => "",
                value     => {qw( test hash var 43 )},
            },
        },
    )
}

sub _define_cases_hash_clone {
    (
        {
            name => "hash with clone",
            args => {
                -variable => \%test_hash,
            },
            actions => sub {
                $clone           = Storable::dclone( \%test_hash );
                $clone->{test}   = "cloned_test_hash3";
                $test_hash{test} = 'updated_test_hash3';
            },
            expected => {
                watch_obj => 1,
                stdout    => "",
                value     => {qw( test updated_test_hash3 )},
                clone     => {qw( test cloned_test_hash3 )},
            },
        },
        {
            name => "hash with clone - fetch",
            args => {
                -variable => \%test_hash,
                -fetch    => sub { 42 },
            },
            actions => sub {
                $clone           = Storable::dclone( \%test_hash );
                $clone->{test}   = "cloned_test_hash3";
                $test_hash{test} = 'updated_test_hash3';
            },
            expected => {
                watch_obj => 1,
                stdout    => "",
                value     => {qw( test 42 )},
                clone     => {qw( test 42 )},
            },
        },
        {
            name => "hash with clone - store",
            args => {
                -variable => \%test_hash,
                -store    => sub { shift->Store( shift, 43 ) },
            },
            actions => sub {
                $clone           = Storable::dclone( \%test_hash );
                $clone->{test}   = "cloned_test_hash3";
                $test_hash{test} = 'updated_test_hash3';
            },
            expected => {
                watch_obj => 1,
                stdout    => "",
                value     => {qw( test 43 )},
                clone     => {qw( test 43 )},
            },
        },
    )
}

sub _define_cases_hash_no_clone {
    (
        {
            name => "hash no clone",
            args => {
                -variable => \%test_hash,
                -clone    => 0,
            },
            actions => sub {
                $clone           = Storable::dclone( \%test_hash );
                $clone->{test}   = "cloned_test_hash4";
                $test_hash{test} = 'updated_test_hash4';
            },
            expected => {
                watch_obj => 1,
                stdout    => "",
                value     => {qw( test updated_test_hash4 )},
                clone     => {qw( test cloned_test_hash4 )},
            },
        },
        {
            name => "hash no clone - fetch",
            args => {
                -variable => \%test_hash,
                -fetch    => sub { 42 },
                -clone    => 0,
            },
            actions => sub {
                $clone           = Storable::dclone( \%test_hash );
                $clone->{test}   = "cloned_test_hash5";
                $test_hash{test} = 'updated_test_hash5';
            },
            expected => {
                watch_obj => 1,
                stdout    => "",
                value     => {qw( test 42 )},
                clone     => {qw( test cloned_test_hash5 )},
            },
        },
        {
            name => "hash no clone - store",
            args => {
                -variable => \%test_hash,
                -store    => sub { shift->Store( shift, 43 ) },
                -clone    => 0,
            },
            actions => sub {
                $clone           = Storable::dclone( \%test_hash );
                $clone->{test}   = "cloned_test_hash6";
                $test_hash{test} = 'updated_test_hash6';
            },
            expected => {
                watch_obj => 1,
                stdout    => "",
                value     => {qw( test 43 )},
                clone     => {qw( test cloned_test_hash6 )},
            },
        },
    )
}

my @cases = (

    # User Errors
    _define_cases_stack_trace(),

    # Scalar
    _define_cases_scalar_basic(),
    _define_cases_scalar_clone(),
  # _define_cases_scalar_no_clone(),

  # # Array
  # _define_cases_array_basic(),
  # _define_cases_array_clone(),
  # _define_cases_array_no_clone(),

  # # Hash
  # _define_cases_hash_basic(),
  # _define_cases_hash_clone(),
  # _define_cases_hash_no_clone(),

);

for my $case ( @cases ) {
    say "\ncase: " . Dumper($case) if $case->{debug};

    # Setup trace.
    my $args = $case->{args} // [];
    
    # Compare stdout and return when using wantarray.
    if ($case->{trace_only}) {
        my ($stdout_noret,$return_noret) = run(
            sub{ Trace( @$args )  },
            0,
        );
        my ($stdout_ret,$return_ret) = run(
            sub{ Trace( @$args ) }
        );

        like (
            $stdout_noret,
            $case->{expected}{stdout},
            "$case->{name} - stdout_noret",
        );
        is (
            $return_noret,
            undef,
            "$case->{name} - return_noret",
        );
        is (
            $stdout_ret,
            "",
            "$case->{name} - stdout_ret",
        );
        like (
            $return_ret,
            $case->{expected}{stdout},
            "$case->{name} - return_ret",
        );
    
        last if $case->{debug};
        next;
    }

    my ($stdout,@refs) = run( sub{ Trace( @$args ) });
    is (
        $stdout,
        "",
        "$case->{name} - stdout",
    );
    say "stdout: [$stdout]" if $case->{debug};

    # Run actions.
    if ( $case->{actions} ) {
        ($stdout) = run(
            sub { $case->{actions}->( $case ) }
        );
        say "stdout2: [$stdout]" if $case->{debug};
    }

    # Check STDOUT.
    if ( $case->{expected}{stdout} ) {
        like (
            $stdout,
            $case->{expected}{stdout},
            "$case->{name} - stdout2",
        );
    }

    # Check for variable values afterwards.
    if ( $case->{expected}{variable} ) {
      # use e;
      # p $case;
      # p \$test_scalar;
        is_deeply(
            $case->{expected}{variable},
            $case->{expected}{value},
            "$case->{name} - value",
        );
    }

    # Check for clone values afterwards (if any).
    if ( exists $case->{expected}{clone} ) {
        is_deeply( $clone, $case->{expected}{clone}, "$case->{name} - clone", );
    }

    # Cleanup for the next call.
    if ( $case->{expected}{variable} ) {
        $_->Unwatch() for @refs;
    }
    reset_vars();

    last if $case->{debug};
}

done_testing();
