#!/usr/bin/env perl
use strict;
use warnings FATAL => 'all';
use Module::Build;

my $builder = Module::Build->new(
    module_name    => 'Browser::Extension::MinVer',
    dist_version   => '0.2.0',
    dist_abstract  => 'A script for finding out minimum version needed for a browser extension.',
    license        => 'GPL_3',
    dist_author    => 'fluks <fluks.github@gmail.com>',
    release_status => 'unstable',
    configure_requires => {
        'Module::Build' => 0,
    },
    requires => {
        perl              => '5.22.0',
        Readonly          => 0,
        'File::ShareDir'  => 0,
    },
    create_makefile_pl => 'traditional',
    script_files       => [
        'bin/min_ext_ver.pl',
        'bin/parse_compatibility_table.pl',
    ],
    share_dir => 'data',
);

$builder->create_build_script();
