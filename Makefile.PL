use strict;
use warnings FATAL => 'all';
use ExtUtils::MakeMaker;

(do 'maint/Makefile.PL.include' or die $@) unless -f 'META.yml';

WriteMakefile(
  NAME => 'Daemon::Control::Starman',
  VERSION_FROM => 'lib/Daemon/Control/Starman.pm',

  EXE_FILES => [],

  PREREQ_PM => {
    'Daemon::Control'   => 0,
    'Server::Starter'   => 0,
    'Starman'           => 0,
    'Net::Server::SS::PreFork' => 0,
    'Try::Tiny'         => 0,
  },
);
