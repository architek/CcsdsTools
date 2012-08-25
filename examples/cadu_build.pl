#!/usr/bin/perl
use strict;
use warnings;

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Generates random frames with included random packets
#Not done: OID frames and idle packets
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

BEGIN { require "Custo.pm" }
use Ccsds::TM::SourcePacket qw($TMSourcePacket);
use Ccsds::TM::Frame qw($TMFrame);
use Ccsds::Utils qw(patch_crc is_idle);
use CcsdsTools::Cadu::CaduGen "cadu_gen";
use Data::Dumper;

#Packet vars
my $weight_apid_1 = {
    45 => 3,
    8  => 4,

    #    2047 => 1,  # TODO
};
my %dist_apid_1;

my $weight_apid_2 = {
    46 => 3,
    9  => 5,

    #    2047 => 1,  # TODO
};
my %dist_apid_2;

#*Source Data* Length distribution
my $weight_len = {
    260   => 10,
    665   => 2,
    1000  => 1,
    2000  => 1,
    16899 => 3,
};
my %dist_len;

#this generates a pattern of 475254 bytes .Check with  print scalar(()=('a' .. 'zzzz'))
#a .. z then aa,ab, ac .. az, ba,bb, bc .. bz, ..zz, etc...
#my $pattern = join '', 'a'..'zzzz';
my $pattern = ( join '', 'a' .. 'z' ) x 1000;

my $g_obt = 0;

#Next ssc per apid to use
my %ssc;

my $def_pkt = {
    'Packet Header' => {
        'Length'                  => 6,
        'Packet Sequence Control' => {
            'Source Seq Count'   => 16383,
            'Packet Length'      => 18,
            'Segmentation Flags' => 3
        },
        'Packet Id' => {
            'vApid'          => 70,
            'DFH Flag'       => 1,
            'Type'           => 0,
            'Version Number' => 0,
            'Apid'           => {
                'PID'  => 4,
                'Pcat' => 6
            }
        }
    },
    'Packet Data Field' => {
        'Packet Error Control'    => 6375,
        'TMSourceSecondaryHeader' => {
            'Length'   => 12,
            'Sat_Time' => {
                'CUC Fine'   => [ 18, 189, 123 ],
                'CUC Coarse' => [ 0,  0,   83, 93 ],
                'OBT' => '21341.0732037425'
            },
            'Time Quality'      => 0,
            'Destination Id'    => 0,
            'Service Subtype'   => 3,
            'Service Type'      => 5,
            'SecHeadFirstField' => {
                'Spare1'             => 0,
                'Spare2'             => 0,
                'PUS Version Number' => 1
            }
        },
        'Source Data' => 'ABCDE',
    },
    'Has Crc' => 1
};

#Frame vars
my $nf                 = 1000;
my @frm_count          = (0) x 128;
my $frm_mast_count     = 0;
my $frm_data_size      = 1105;
my $rs_size            = 160;
my $max_frm_count      = 256;
my $max_frm_mast_count = 256;
my %vc_to_apid;

my $weight_OID = {
    0 => 90,
    1 => 10,                            # 10% of OID
};
my %dist_OID;

my $weight_vc = {
    6 => 10,
    5 => 1,
};
my %dist_vc;

my $def_frm = {
    'CLCW' => {
        'NoBitLock'          => 1,
        'Report Value'       => 0,
        'Retransmit'         => 0,
        'NoRFAvail'          => 1,
        'Virtual Channel ID' => 62,
        'Ctrl World'         => 0,
        'COP in effect'      => 1,
        'Status Field'       => 0,
        'Wait'               => 0,
        'Spare'              => 0,
        'CLCW Version'       => 0,
        'FarmB Counter'      => 2,
        'Lockout'            => 1
    },
    'TM Frame Secondary Header' => undef,
    'Data'                      => 'A',
    'TM Frame Header'           => {
        'First Header Pointer'        => 10,
        'Virtual Channel Frame Count' => 178,
        'SpaceCraftId'                => 569,
        'Segment Length Id'           => 3,
        'Operation Flag'              => 1,
        'Master Channel Frame Count'  => 213,
        'Length'                      => 6,
        'Packet Order Flag'           => 0,
        'Sync Flag'                   => 0,
        'Virtual Channel Id'          => 1,
        'Sec Header'                  => 0,
        'Version Number Frame'        => 0
    }
};

# weight_to_dist: takes a hash mapping key to weight and returns
# a hash mapping key to probability
sub weight_to_dist {
    my %weights = @_;
    my %dist    = ();
    my $total   = 0;
    my ( $key, $weight );
    local $_;

    foreach ( values %weights ) {
        $total += $_;
    }

    while ( ( $key, $weight ) = each %weights ) {
        $dist{$key} = $weight / $total;
    }

    return %dist;
}

# weighted_rand: takes a hash mapping key to probability, and
# returns the corresponding element
sub weighted_rand {
    my %dist = @_;
    my ( $key, $weight );

    while (1) {    # to avoid floating point inaccuracies
        my $rand = rand;
        while ( ( $key, $weight ) = each %dist ) {
            return $key if ( $rand -= $weight ) < 0;
        }
    }
    return;
}

#Packet infos builders

sub get_next_pid_pcat {
    my ($vc) = @_;
    my $apid = weighted_rand %{ $vc_to_apid{$vc} };
    return ( $apid >> 4, $apid % 16, $apid );
}

sub get_next_len {
    return weighted_rand %dist_len;
}

sub get_next_obt {
    my ( $obt, $ms ) = @_;
    $$obt += $ms / 1_000;
    my $coarse = int($$obt);
    my $fine   = $$obt - $coarse;

    #CUC 4,3
    return unpack 'C4xC3', pack( 'N2', $coarse, $fine * ( 2**24 - 1 ) );
}

#Returns a packet based on a template packet modified by normal distribution
sub mod_def {
    my ( $pkt, $vc ) = @_;

    my $ph = $pkt->{'Packet Header'};

    #APID
    my ( $pid, $pcat, $apid ) = get_next_pid_pcat $vc;
    $ph->{'Packet Id'}{'Apid'}{'PID'}  = $pid;
    $ph->{'Packet Id'}{'Apid'}{'Pcat'} = $pcat;
    $ph->{'Packet Id'}{'vApid'}        = $apid;    # this one is only needed for next is_idle

    #SSC
    $ph->{'Packet Sequence Control'}{'Source Seq Count'} = ( exists $ssc{$apid} ) ? $ssc{$apid} : 0;
    $ssc{$apid} = ( ++$ssc{$apid} ) & 16383;

    #LEN
    my $len       = get_next_len;
    my $ccsds_len = $len - 1 + $pkt->{'Packet Data Field'}{TMSourceSecondaryHeader}{Length};
    $ccsds_len += 2 unless is_idle($pkt);
    $ph->{'Packet Sequence Control'}{'Packet Length'} = $ccsds_len;

    #OBT
    my ( $c1, $c2, $c3, $c4, $f1, $f2, $f3 ) = get_next_obt \$g_obt, $ccsds_len;
    my $sat = $pkt->{'Packet Data Field'}{'TMSourceSecondaryHeader'}{'Sat_Time'};
    @{ $sat->{'CUC Coarse'} } = ( $c1, $c2, $c3, $c4 );
    @{ $sat->{'CUC Fine'} } = ( $f1, $f2, $f3 );

    #DATA
    $pkt->{'Packet Data Field'}{'Source Data'} = substr $pattern, 0, $len;

    return %{$pkt};
}

sub gen_next_pkt {
    my %pkt = @_;
    my $raw = $TMSourcePacket->build( \%pkt );
    patch_crc( \$raw ) if $pkt{'Has Crc'};
    return $raw;
}

#Frame infos builders

sub get_next_frm_counter {
    my ($vc) = @_;
    my ( $v, $m ) = ( $frm_count[$vc], $frm_mast_count );
    $frm_count[$vc] = ( $frm_count[$vc] + 1 ) % $max_frm_count;
    $frm_mast_count = ( $frm_mast_count + 1 ) % $max_frm_mast_count;
    return ( $v, $m );
}

sub gen_next_frm {
    my ( $ldef_frm, $frm_data, $fhp, $vc ) = @_;
    $ldef_frm->{Data}                                        = $frm_data;
    $ldef_frm->{'TM Frame Header'}->{'First Header Pointer'} = $fhp;
    $ldef_frm->{'TM Frame Header'}->{'Virtual Channel Id'}   = $vc;
    my ( $vc_count, $master_count ) = get_next_frm_counter $vc;
    $ldef_frm->{'TM Frame Header'}{'Virtual Channel Frame Count'} = $vc_count;
    $ldef_frm->{'TM Frame Header'}{'Master Channel Frame Count'}  = $master_count;
    return $ldef_frm;
}

sub frm_to_cadu {
    my ($data) = @_;
    return "\x1a\xcf\xfc\x1d" . $data . substr( $pattern, 0, $rs_size );
}

sub tm_decode {
    my ( $tm, $raw ) = @_;
    #    print Dumper $tm;
}

sub extract_tmfe_record {
    my ( $frame, undef, $rec_head ) = @_;
    #    print "=" x 30 , "\n", Dumper($frame);
}

my %ssc_apid;

sub ssc_gapCheck {
    my ($packet) = @_;
    my $apid = $packet->{'Packet Header'}->{'Packet Id'}->{'vApid'};
    unless ( is_idle($packet) ) {
        my $ssc = $packet->{'Packet Header'}->{'Packet Sequence Control'}->{'Source Seq Count'};
        if ( defined $ssc_apid{$apid} and ( ( $ssc - $ssc_apid{$apid} ) & 16383 ) != 1 ) {
            print "ERROR: SSC Gap from $ssc_apid{$apid} to $ssc for Apid $apid\n\n";
        }
        $ssc_apid{$apid} = $ssc;
    }
}

my ( $mfc, %vfc );
my $scid;

sub frame_gapCheck {
    my ($frame) = @_;

    my $tfh   = $frame->{'TM Frame Header'};
    my $vc_id = $tfh->{'Virtual Channel Id'};
    my $sc_id = $tfh->{SpaceCraftId};
    my $vc_fc = $tfh->{'Virtual Channel Frame Count'};
    my $mc_fc = $tfh->{'Master Channel Frame Count'};

    printf "SCID Gap from %d to %d\n\n", $scid, $sc_id
      if defined($scid)
      and $scid != $sc_id;
    $scid = $sc_id;

    #Mfc gap can't be really detected properly
    #    printf "t=%.2fs VC %d: Master Frame counter Gap from %d to %d\n\n",$bench_time,$vc_id,$mfc ,$mc_fc
    #            if defined($mfc) and (($mc_fc-$mfc) & 0xFF) != 1;
    $mfc = $mc_fc;

    printf "ERROR: VC %d: Virtual Channel counter Gap from %d to %d\n\n", $vc_id, $vfc{$vc_id}, $vc_fc
      if defined( $vfc{$vc_id} )
      and ( ( $vc_fc - $vfc{$vc_id} ) & 0xFF ) != 1;
    $vfc{$vc_id} = $vc_fc;
}

sub frm_code { 
    return ( weighted_rand (%dist_vc), $frm_data_size , 0);
}
sub pkt_code { 
    my ($vc) = @_;
    my %pkt = mod_def $def_pkt, $vc; 
    return gen_next_pkt %pkt;
}
sub cadu_code {
    my ($frm_data, $fhp, $vc) = @_;
    my $frm     = gen_next_frm $def_frm, $frm_data, $fhp, $vc;
    my $frm_raw = $TMFrame->build($frm);
    return frm_to_cadu $frm_raw;
}

#Start
#~~~~~~

%dist_apid_1 = weight_to_dist %$weight_apid_1;
%dist_apid_2 = weight_to_dist %$weight_apid_2;
%dist_len    = weight_to_dist %$weight_len;
%dist_vc     = weight_to_dist %$weight_vc;
%dist_OID    = weight_to_dist %$weight_OID;
$vc_to_apid{6} = \%dist_apid_1;
$vc_to_apid{5} = \%dist_apid_2;

my $binfile = shift // "tmp_cadu";
cadu_gen($nf, $binfile, \&frm_code, \&pkt_code, \&cadu_code );
