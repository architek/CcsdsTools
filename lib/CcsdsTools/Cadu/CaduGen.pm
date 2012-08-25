#
#===============================================================================
#
#         FILE: CaduGen.pm
#
#  DESCRIPTION: Generates CADU flow from packets provided by the user
#
#         TODO: OID frames and idle packets
#      CREATED: 23/08/2012 23:06:56
#===============================================================================

use strict;
use warnings;

package CcsdsTools::Cadu::CaduGen;

=head1 NAME

CcsdsTools::Cadu::CaduGen - Module used to assemble packets into CADUs

=cut

require Exporter;
use base qw/Exporter/;
our @EXPORT_OK = qw /cadu_gen/;

sub cadu_gen {
    my ( $nf, $binfile, $frm_code, $pkt_code, $cadu_code ) = @_;
    my @data_vc = ("") x 128;

    open my $fin, ">:raw", $binfile or die "can not open $binfile for writing";
    warn "Generating $nf cadus to file $binfile\n";

    for ( my $i = 0 ; $i < $nf ; $i++ ) {
        my ( $vc, $frm_data_size, $is_oid ) = $frm_code->();
        my $fhp;
        my $frm_data = "";
        my $len      = $frm_data_size;

        if ( 0 and $is_oid ) {    # Not done
            $vc  = 7;
            $fhp = 0b11111111110;

            #$frm_data = substr $pattern, 0, $frm_data_size;
        }
        else {
            $fhp = 0b11111111111;
            while ($len) {
                unless ( length( $data_vc[$vc] ) ) {
                    $data_vc[$vc] = $pkt_code->($vc);
                    $fhp = $frm_data_size - $len if $fhp == 0b11111111111;
                }
                my $min = $len < length( $data_vc[$vc] ) ? $len : length( $data_vc[$vc] );
                $frm_data .= substr( $data_vc[$vc], 0, $min );
                $len -= $min;
                substr $data_vc[$vc], 0, $min, "";
            }
        }
        my $cadu = $cadu_code->( $frm_data, $fhp, $vc );
        print $fin $cadu;
    }
    close $fin;
}

=head1 SYNOPSIS

This library is basically a loop to assemble packets into CADUs. As parameter to this module, the user is supposed to pass several function references and a filename.
 * The first function returns the next virtual channel to use as well as frame data length (should be fix for a mission..) and boolean which is true if the next frame should be an OID
 * The second function returns a packet: it receives as input the virtual channel in case it is needed and in return it must provide raw binary packet
 * The third function returns a CADU: it receives as input the frame data, the first header pointer and the virtual channel id and in return it must provide a raw binary Cadu.

The calling app can use any library to build the raw binary packets and cadus.
Packets are assembled with First Header Pointer handling and CADUS are written in binary to the file.

=head1 EXPORTS

=head2 cadu_gen ( n, filename, code_frame, code_pkt, code_cadu )

    * n Cadus to generate
    * filename is the name of the file to generate cadus to
    * code_frame returns the next virtual channel to use and boolean which is true if the next frame should be an OID (not done currently)
    * code_pkt is a sub ref which gets as parameter : virtual channel id of the current frame. returns binary packet.
    * code_cadu is a sub ref which gets as parameters: frame data, fhp, virtual channel id . returns binary cadu.

=head1 AUTHOR

Laurent KISLAIRE, C<< <teebeenator at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<teebeenator at gmail.com>

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc CCsdsTools::Cadu::CaduGen;

=head1 LICENSE AND COPYRIGHT

Copyright 2012 Laurent KISLAIRE.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;

