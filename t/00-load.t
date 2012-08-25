#!perl -T

use Test::More tests => 2;

BEGIN {
    use_ok( 'CcsdsTools' ) || print "Bail out!  ";
    use_ok( 'CcsdsTools::Cadu::CaduGen' ) || print "Bail out!  ";
}

diag( "Testing CcsdsTools Library loading $CcsdsTools::VERSION, Perl $], $^X" );
