#Sample customization 
#############################
package Ccsds::Custo;
use Data::ParseBinary;

our $config_tm = {
    output   =>   {
        debug=>0,          #internal debug
        data=>0,           #dump content of protocol units
    },
    TMSourcePacketHeaderLength => 6,
    record_len      => 4 + 1115 + 160,
    offset_data     => 4,
    frame_len       => 1115,
    has_sync        => 1,
    coderefs_packet => [ \&main::tm_decode , \&main::ssc_gapCheck ],
    coderefs_frame  => [ \&main::extract_tmfe_record , \&main::frame_gapCheck ],
};

our $has_crc=Value('Has Crc',
    sub {
      ( $_->ctx->{'Packet Header'}->{'Packet Id'}->{'vApid'} != 2047 &&
        $_->ctx->{'Packet Header'}->{'Packet Id'}->{'vApid'} != 29
      ) ? 1 : 0 ;
    }
);

1;
