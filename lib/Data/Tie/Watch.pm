$Data::Tie::Watch::VERSION = '1.302';

package Data::Tie::Watch;

=head1 NAME

 Data::Tie::Watch - place watchpoints on Perl variables.

=head1 SYNOPSIS

 use Data::Tie::Watch;

 $watch = Data::Tie::Watch->new(
     -variable => \$frog,
     -shadow   => 0,			  
     -fetch    => [\&fetch, 'arg1', 'arg2', ..., 'argn'],
     -store    => \&store,
     -destroy  => sub {print "Final value=$frog.\n"},
 }
 $val   = $watch->Fetch;
 $watch->Store('Hello');
 $watch->Unwatch;

=head1 DESCRIPTION

Note: This is a copy of Tk's Tie::Watch.
Copied to avoid the Tk depedency.

This class module binds one or more subroutines of your devising to a
Perl variable.  All variables can have B<FETCH>, B<STORE> and
B<DESTROY> callbacks.  Additionally, arrays can define B<CLEAR>,
B<DELETE>, B<EXISTS>, B<EXTEND>, B<FETCHSIZE>, B<POP>, B<PUSH>,
B<SHIFT>, B<SPLICE>, B<STORESIZE> and B<UNSHIFT> callbacks, and hashes
can define B<CLEAR>, B<DELETE>, B<EXISTS>, B<FIRSTKEY> and B<NEXTKEY>
callbacks.  If these term are unfamiliar to you, I I<really> suggest
you read L<perltie>.

With Data::Tie::Watch you can:

 . alter a variable's value
 . prevent a variable's value from being changed
 . invoke a Perl/Tk callback when a variable changes
 . trace references to a variable

Callback format is patterned after the Perl/Tk scheme: supply either a
code reference, or, supply an array reference and pass the callback
code reference in the first element of the array, followed by callback
arguments.  (See examples in the Synopsis, above.)

Tie::Watch provides default callbacks for any that you fail to
specify.  Other than negatively impacting performance, they perform
the standard action that you'd expect, so the variable behaves
"normally".  Once you override a default callback, perhaps to insert
debug code like print statements, your callback normally finishes by
calling the underlying (overridden) method.  But you don't have to!

To map a tied method name to a default callback name simply lowercase
the tied method name and uppercase its first character.  So FETCH
becomes Fetch, NEXTKEY becomes Nextkey, etcetera.

=head1 METHODS

=over 4

=item $watch = Data::Tie::Watch->new(-options => values);

The watchpoint constructor method that accepts option/value pairs to
create and configure the Watch object.  The only required option is
B<-variable>.

B<-variable> is a I<reference> to a scalar, array or hash variable.

B<-shadow> (default 1) is 0 to disable array and hash shadowing.  To
prevent infinite recursion Data::Tie::Watch maintains parallel variables for
arrays and hashes.  When the watchpoint is created the parallel shadow
variable is initialized with the watched variable's contents, and when
the watchpoint is deleted the shadow variable is copied to the original
variable.  Thus, changes made during the watch process are not lost.
Shadowing is on by default.  If you disable shadowing any changes made
to an array or hash are lost when the watchpoint is deleted.

Specify any of the following relevant callback parameters, in the
format described above: B<-fetch>, B<-store>, B<-destroy>.
Additionally for arrays: B<-clear>, B<-extend>, B<-fetchsize>,
B<-pop>, B<-push>, B<-shift>, B<-splice>, B<-storesize> and
B<-unshift>.  Additionally for hashes: B<-clear>, B<-delete>,
B<-exists>, B<-firstkey> and B<-nextkey>.

=item $watch->Fetch();  $watch->Fetch($key);

Returns a variable's current value.  $key is required for an array or
hash.

=item $watch->Store($new_val);  $watch->Store($key, $new_val);

Store a variable's new value.  $key is required for an array or hash.

=item $watch->Unwatch();

Stop watching the variable.

=back

=head1 EFFICIENCY CONSIDERATIONS

If you can live using the class methods provided, please do so.  You
can meddle with the object hash directly and improved watch
performance, at the risk of your code breaking in the future.

=head1 AUTHOR

Stephen O. Lidie

=head1 HISTORY

 lusol@Lehigh.EDU, LUCC, 96/05/30
 . Original version 0.92 release, based on the Trace module from Hans Mulder,
   and ideas from Tim Bunce.

 lusol@Lehigh.EDU, LUCC, 96/12/25
 . Version 0.96, release two inner references detected by Perl 5.004.

 lusol@Lehigh.EDU, LUCC, 97/01/11
 . Version 0.97, fix Makefile.PL and MANIFEST (thanks Andreas Koenig).
   Make sure test.pl doesn't fail if Tk isn't installed.

 Stephen.O.Lidie@Lehigh.EDU, Lehigh University Computing Center, 97/10/03
 . Version 0.98, implement -shadow option for arrays and hashes.

 Stephen.O.Lidie@Lehigh.EDU, Lehigh University Computing Center, 98/02/11
 . Version 0.99, finally, with Perl 5.004_57, we can completely watch arrays.
   With tied array support this module is essentially complete, so its been
   optimized for speed at the expense of clarity - sorry about that. The
   Delete() method has been renamed Unwatch() because it conflicts with the
   builtin delete().

 Stephen.O.Lidie@Lehigh.EDU, Lehigh University Computing Center, 99/04/04
 . Version 1.0, for Perl 5.005_03, update Makefile.PL for ActiveState, and
   add two examples (one for Perl/Tk).

 sol0@lehigh.edu, Lehigh University Computing Center, 2003/06/07
 . Version 1.1, for Perl 5.8, can trace a reference now, patch from Slaven
   Rezic.

 sol0@lehigh.edu, Lehigh University Computing Center, 2005/05/17
 . Version 1.2, for Perl 5.8, per Rob Seegel's suggestion, support array
   DELETE and EXISTS.

=head1 COPYRIGHT

Copyright (C) 1996 - 2005 Stephen O. Lidie. All rights reserved.

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

use 5.004_57;
use Carp;
use strict;
use Scalar::Util qw( reftype weaken );
use e;

our %METHODS;

# Watch constructor.  The *real* constructor is Data::Tie::Watch->base_watch(),
# invoked by methods in other Watch packages, depending upon the variable's
# type.  Here we supply defaulted parameter values and then verify them,
# normalize all callbacks and bind the variable to the appropriate package.

sub new {
    my $class = shift;
    my %args  = (
        -shadow => 1,
        -clone  => 1,    # Clones are also watched.
        @_,
    );

    croak "-variable is required!" if !$args{-variable};

    my $methods = $class->_build_methods( %args );
    for ( keys %args ) {

        # Skip -shadow like options.
        next if reftype( $args{$_} ) ne "CODE";

        if ( $methods->{$_} ) {

            # Assign new valide method from arguments.
            $methods->{$_} = delete $args{$_};
        }
        else {
            # Able to pass in more options for
            # simplicity. Exclude them here.
            delete $args{$_};
        }
    }

    my $watch_obj = $class->_build_obj( %args );
    $METHODS{ $watch_obj->{id} } = $methods;

    $watch_obj;
}

sub _build_methods {
    my ( $class, %args ) = @_;
    my $var  = $args{-variable};
    my $type = reftype( $var );
    my %methods;

    if ( $type =~ /(SCALAR|REF)/ ) {
        %methods = (
            -destroy => \&Data::Tie::Watch::Scalar::Destroy,
            -fetch   => \&Data::Tie::Watch::Scalar::Fetch,
            -store   => \&Data::Tie::Watch::Scalar::Store,
        );
    }
    elsif ( $type =~ /ARRAY/ ) {
        %methods = (
            -clear     => \&Data::Tie::Watch::Array::Clear,
            -delete    => \&Data::Tie::Watch::Array::Delete,
            -destroy   => \&Data::Tie::Watch::Array::Destroy,
            -exists    => \&Data::Tie::Watch::Array::Exists,
            -extend    => \&Data::Tie::Watch::Array::Extend,
            -fetch     => \&Data::Tie::Watch::Array::Fetch,
            -fetchsize => \&Data::Tie::Watch::Array::Fetchsize,
            -pop       => \&Data::Tie::Watch::Array::Pop,
            -push      => \&Data::Tie::Watch::Array::Push,
            -shift     => \&Data::Tie::Watch::Array::Shift,
            -splice    => \&Data::Tie::Watch::Array::Splice,
            -store     => \&Data::Tie::Watch::Array::Store,
            -storesize => \&Data::Tie::Watch::Array::Storesize,
            -unshift   => \&Data::Tie::Watch::Array::Unshif,
        );
    }
    elsif ( $type =~ /HASH/ ) {
        %methods = (
            -clear    => \&Data::Tie::Watch::Hash::Clear,
            -delete   => \&Data::Tie::Watch::Hash::Delete,
            -destroy  => \&Data::Tie::Watch::Hash::Destroy,
            -exists   => \&Data::Tie::Watch::Hash::Exists,
            -fetch    => \&Data::Tie::Watch::Hash::Fetch,
            -firstkey => \&Data::Tie::Watch::Hash::Firstkey,
            -nextkey  => \&Data::Tie::Watch::Hash::Nextkey,
            -store    => \&Data::Tie::Watch::Hash::Stor,
        );
    }
    else {
        croak "Data::Tie::Watch::new() - not a variable reference.";
    }

    \%methods;
}

sub _build_obj {
    my ( $class, %args ) = @_;
    my $var  = $args{-variable};
    my $type = reftype( $var );
    my $watch_obj;

    if ( $type =~ /(SCALAR|REF)/ ) {
        $watch_obj = tie $$var, 'Data::Tie::Watch::Scalar', %args;
    }
    elsif ( $type =~ /ARRAY/ ) {
        $watch_obj = tie @$var, 'Data::Tie::Watch::Array', %args;
    }
    elsif ( $type =~ /HASH/ ) {
        $watch_obj = tie %$var, 'Data::Tie::Watch::Hash', %args;
    }

    $watch_obj->{id}   = "$watch_obj";
    $watch_obj->{type} = $type;

  # weaken $watch_obj->{-variable};

    $watch_obj;
}

# Clean up global cache.
sub DESTROY {
    $_[0]->callback( '-destroy' );
    delete $METHODS{"$_[0]"};
}

# Stop watching a variable by releasing the last reference and untieing it.
# Update the original variable with its shadow, if appropriate.
#
# $_[0] = self

sub Unwatch {
    trace;
    my $var = $_[0]->{-variable};
    return if not $var;

    my $type = reftype( $var );
    return if not $type;

    my $copy;
    $copy = $_[0]->{-ptr} if $type !~ /(SCALAR|REF)/;
    my $shadow = $_[0]->{-shadow};
    undef $_[0];

    if ( $type =~ /(SCALAR|REF)/ ) {
        say "untie scalar";
        untie $$var;
    }
    elsif ( $type =~ /ARRAY/ ) {
        say "untie array";
        untie @$var;
        @$var = @$copy if $shadow;
    }
    elsif ( $type =~ /HASH/ ) {
        say "untie hash";
        untie %$var;
        say "copy:";
        d $copy;
        %$var = %$copy if $shadow;
        return;
    }
    else {
        croak "not a variable reference.";
    }
}

=head2 base_watch

Watch base class constructor invoked by other Watch modules.

=cut

sub base_watch {
    my ( $class, %args ) = @_;
    +{%args};
}

=head2 callback

 Execute a Watch callback, either the default or user specified.
 Note that the arguments are those supplied by the tied method,
 not those (if any) specified by the user when the watch object
 was instantiated.  This is for performance reasons.

 $_[0] = self
 $_[1] = callback type
 $_[2] through $#_ = tied arguments

=cut

sub callback {
    my ( $watch_obj, $mkey, @args ) = @_;
    my $id =
        $watch_obj->{-clone}
      ? $watch_obj->{id}
      : "$watch_obj";

    if ( $METHODS{$id} && $METHODS{$id}{$mkey} ) {
        print "GOT METHOD: $mkey (@args)\n";
        print "  $watch_obj\n";
        return $METHODS{$id}{$mkey}->( $watch_obj, @args, );
    }

    my $method_name = $mkey =~ s/^-(\w+)/\L\u$1/r;
    my $method      = sprintf( "Data::Tie::Watch::%s::%s",
        "\L\u$watch_obj->{type}\E", $method_name, );
    print "NO METHOD: $mkey (@args)\n";
    print "  $watch_obj\n";
    print "  $method\n";

    # Should also finish its current action.
    my @return;
    {
        no strict 'refs';
        say "run $mkey (@args)";
        @return = $method->( $watch_obj, @args );
    }

    say "return:";
    d \@return;

    # Untie.
    # Do NOT run any callback methods after this
    # point in order to avoid SEGMENTATION errors!
  # $watch_obj->Unwatch();
    my $var  = $watch_obj->{-variable};
    my $copy = $watch_obj->{-ptr};
    
  # say "untie hash";    
    untie %$var;
    
    say "copy:";
    d $copy;

    %$var = %$copy;

  # say "var:";
  # d $var;

    return @return if wantarray;
    return $return[0];
}

###############################################################################

package # temporarily disabled from PAUSE indexer because of permission problems
  Data::Tie::Watch::Scalar;

use Carp;
our @ISA = qw( Data::Tie::Watch );

sub TIESCALAR {
    my ( $class, %args ) = @_;
    my $variable  = $args{-variable};
    my $watch_obj = Data::Tie::Watch->base_watch( %args );

    $watch_obj->{-value} = $$variable;

    bless $watch_obj, $class;
}

# Default scalar callbacks.

sub Destroy { undef %{ $_[0] } }
sub Fetch   { $_[0]->{-value} }
sub Store   { $_[0]->{-value} = $_[1] }

# Scalar access methods.

sub FETCH { $_[0]->callback( '-fetch' ) }
sub STORE { $_[0]->callback( '-store', $_[1] ) }

###############################################################################

package # temporarily disabled from PAUSE indexer because of permission problems
  Data::Tie::Watch::Array;

use Carp;
our @ISA = qw( Data::Tie::Watch );

sub TIEARRAY {
    my ( $class,    %args )   = @_;
    my ( $variable, $shadow ) = @args{ -variable, -shadow };
    my @copy;
    @copy = @$variable if $shadow;         # make a private copy of user's array
    $args{-ptr} = $shadow ? \@copy : [];
    my $watch_obj = Data::Tie::Watch->base_watch( %args );

    bless $watch_obj, $class;
}

# Default array callbacks.

sub Clear     { $_[0]->{-ptr} = () }
sub Delete    { delete $_[0]->{-ptr}->[ $_[1] ] }
sub Destroy   { undef %{ $_[0] } }
sub Exists    { exists $_[0]->{-ptr}->[ $_[1] ] }
sub Extend    { }
sub Fetch     { $_[0]->{-ptr}->[ $_[1] ] }
sub Fetchsize { scalar @{ $_[0]->{-ptr} } }
sub Pop       { pop @{ $_[0]->{-ptr} } }
sub Push      { push @{ $_[0]->{-ptr} }, @_[ 1 .. $#_ ] }
sub Shift     { shift @{ $_[0]->{-ptr} } }

sub Splice {
    my $n = scalar @_;    # splice() is wierd!
    return splice @{ $_[0]->{-ptr} }, $_[1] if $n == 2;
    return splice @{ $_[0]->{-ptr} }, $_[1], $_[2] if $n == 3;
    return splice @{ $_[0]->{-ptr} }, $_[1], $_[2], @_[ 3 .. $#_ ] if $n >= 4;
}
sub Store     { $_[0]->{-ptr}->[ $_[1] ] = $_[2] }
sub Storesize { $#{ $_[0]->{-ptr} } = $_[1] - 1 }
sub Unshift   { unshift @{ $_[0]->{-ptr} }, @_[ 1 .. $#_ ] }

# Array access methods.

sub CLEAR     { $_[0]->callback( '-clear' ) }
sub DELETE    { $_[0]->callback( '-delete', $_[1] ) }
sub EXISTS    { $_[0]->callback( '-exists', $_[1] ) }
sub EXTEND    { $_[0]->callback( '-extend', $_[1] ) }
sub FETCH     { $_[0]->callback( '-fetch',  $_[1] ) }
sub FETCHSIZE { $_[0]->callback( '-fetchsize' ) }
sub POP       { $_[0]->callback( '-pop' ) }
sub PUSH      { $_[0]->callback( '-push', @_[ 1 .. $#_ ] ) }
sub SHIFT     { $_[0]->callback( '-shift' ) }
sub SPLICE    { $_[0]->callback( '-splice',    @_[ 1 .. $#_ ] ) }
sub STORE     { $_[0]->callback( '-store',     $_[1], $_[2] ) }
sub STORESIZE { $_[0]->callback( '-storesize', $_[1] ) }
sub UNSHIFT   { $_[0]->callback( '-unshift',   @_[ 1 .. $#_ ] ) }

###############################################################################

package # temporarily disabled from PAUSE indexer because of permission problems
  Data::Tie::Watch::Hash;

use Carp;
our @ISA = qw( Data::Tie::Watch );

sub TIEHASH {
    my ( $class,    %args )   = @_;
    my ( $variable, $shadow ) = @args{ -variable, -shadow };
    my %copy;
    %copy = %$variable if $shadow;          # make a private copy of user's hash
    $args{-ptr} = $shadow ? \%copy : {};
    my $watch_obj = Data::Tie::Watch->base_watch( %args );

    bless $watch_obj, $class;
}

# Default hash callbacks.

sub Clear    { $_[0]->{-ptr} = () }
sub Delete   { delete $_[0]->{-ptr}->{ $_[1] } }
sub Destroy  { undef %{ $_[0] } }
sub Exists   { exists $_[0]->{-ptr}->{ $_[1] } }
sub Fetch    { $_[0]->{-ptr}->{ $_[1] } }
sub Firstkey { my $c = keys %{ $_[0]->{-ptr} }; each %{ $_[0]->{-ptr} } }
sub Nextkey  { each %{ $_[0]->{-ptr} } }
sub Store    { $_[0]->{-ptr}->{ $_[1] } = $_[2] }

# Hash access methods.

sub CLEAR    { $_[0]->callback( '-clear' ) }
sub DELETE   { $_[0]->callback( '-delete', $_[1] ) }
sub EXISTS   { $_[0]->callback( '-exists', $_[1] ) }
sub FETCH    { $_[0]->callback( '-fetch',  $_[1] ) }
sub FIRSTKEY { $_[0]->callback( '-firstkey' ) }
sub NEXTKEY  { $_[0]->callback( '-nextkey' ) }
sub STORE    { $_[0]->callback( '-store', $_[1], $_[2] ) }

1;
