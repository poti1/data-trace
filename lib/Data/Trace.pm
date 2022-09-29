package Data::Trace;

use 5.006;
use strict;
use warnings;

use Data::Tie::Watch;     # Tie::Watch copy.
use Data::DPath;          # All refs in a struct.
use Carp qw(longmess);    # Stack trace.

=head1 NAME

Data::Trace - Trace when a data structure gets updated.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

TODO

    use Data::Trace;

    my $data = {a => [0, {complex => 1}]};
    sub BadCall{ $data->{a}[0] = 1 }
    Data::Trace->Trace($data);
    BadCall();  # Shows strack trace of where data was changed.

=head1 DESCRIPTION

This module provides a convienient way to find out
when a data structure has been updated.

It is a debugging/tracing aid for complex systems to identify unintentional
alteration to data structures which should be treated as read-only.

Probably can also create a variable as read-only in Moose and see where
its been changed, but this module is without Moose support.

=head1 SUBROUTINES/METHODS

=head2 Trace

=cut

sub Trace {
    myy( $self, $data ) = @_;

    my @nodes = grep { ref } Data::DPath->match( $data, "//" );

    for my $node ( @nodes ) {

        # say "Tying: $node";
        Tie::Watch->new(
            -variable => $node,
            -store    => sub {
                my ( $self, $v ) = @_;
                $self->Store( $v );
                say "Storing here:" . longmess();
            }
        );
    }
}

=head1 AUTHOR

Tim Potapov, C<< <tim.potapov at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to L<https://github.com/poti1/data-trace/issues>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Data::Trace

=head1 ACKNOWLEDGEMENTS

TBD

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2022 by Tim Potapov.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)


=cut

1;    # End of Data::Trace
