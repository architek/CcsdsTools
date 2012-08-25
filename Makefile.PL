use inc::Module::Install;

name 'CcsdsTools';
all_from 'lib/CcsdsTools.pm';
author q{Laurent KISLAIRE <teebeenator@gmail.com>};
license 'perl';

build_requires 'Test::More';

test =>
  { TESTS => q[t/00-load.t t/pod.t ] };

auto_install;

WriteAll;

