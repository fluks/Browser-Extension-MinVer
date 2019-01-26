#!/usr/bin/env perl
use strict;
use warnings;
use feature qw(say signatures);
no warnings 'experimental::signatures';
use English;
use File::Basename;
use JSON;
use File::Spec;
use Data::Dumper;

my $program = basename($0);
my $compat_dir = $ARGV[0] || die <<USAGE;
Usage: $program BROWSER_COMPAT_DATA_DIRECTORY
USAGE

opendir(my $dh, $compat_dir) || die "Can't open $compat_dir: $!";
my $obj = {};
while ((my $dir_entry = readdir $dh)) {
    $dir_entry = File::Spec->catfile($compat_dir, $dir_entry);
    next unless -f $dir_entry;

    open(my $fh, '<', $dir_entry) || do {
        warn "Can't open $dir_entry: $!";
        next;
    };
    undef $INPUT_RECORD_SEPARATOR;
    my $json = decode_json(<$fh>);

    my $lib_json = $json->{webextensions}->{api};
    my $lib = (keys %$lib_json)[0];

    find_symbols($lib_json, '', $obj);
}

$Data::Dumper::Sortkeys = 1;
say Dumper($obj);

sub find_symbols {
    my ($json, $s, $obj) = @_;

    return unless ref $json eq 'HASH';

    my @keys = keys %$json;
    for my $k (@keys) {
        if ($k eq '__compat') {
            return unless exists $json->{__compat}->{mdn_url};

            my $browser_json = $json->{__compat}->{support};
            my @browsers = keys %{ $browser_json };

            for my $brow (@browsers) {
                my $brow_json = $browser_json->{$brow};
                if (ref $brow_json eq 'ARRAY') {
                    for my $version (@$brow_json) {
                        if (exists $version->{alternative_name}) {
                            $obj->{ $version->{alternative_name} }->{$brow} =
                                version_to_value($version->{version_added});
                        }
                        else {
                            $obj->{$s}->{$brow} =
                                version_to_value($version->{version_added});
                        }
                    }
                }
                else {
                    $obj->{$s}->{$brow} =
                        version_to_value($brow_json->{version_added});
                }
            }
        }

        my $symbol = $s ? "$s.$k" : $k;
        find_symbols($json->{$k}, $symbol, $obj);
    }
}

sub version_to_value($version) {
    if (JSON::is_bool($version)) {
        return JSON::true == $version ? 'Yes' : 'No';
    }
    return $version;
}
