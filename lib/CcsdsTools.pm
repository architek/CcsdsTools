#
#===============================================================================
#
#         FILE: CcsdsTools.pm
#
#  DESCRIPTION: Set of tools for Ccsds
#
#      CREATED: 22/08/2012 15:32:31
#===============================================================================

use strict;
use warnings;
 
package CcsdsTools;
our $VERSION="1.0";

=head1 NAME

Ccsds - Module including a set of utilities to work on Ccsds data sets

=cut

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw($VERSION);

=head1 SYNOPSIS

This library includes a set of utilities to work on Ccsds data sets

=head1 AUTHOR

Laurent KISLAIRE, C<< <teebeenator at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<teebeenator at gmail.com>

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc CcsdsTools

=head1 LICENSE AND COPYRIGHT

Copyright 2011 Laurent KISLAIRE.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; 

