#!/usr/bin/env perl
use strict;
use warnings;
use Scalar::Util qw(looks_like_number);
use Readonly;
use List::Util qw(reduce);
use Getopt::Long qw(:config bundling no_ignore_case);
use File::Basename;
use File::Find;
use Data::Dumper;
use feature qw(say signatures);
no warnings 'experimental::signatures';

Readonly::Scalar my $VERSION => '0.1.0';
Readonly::Scalar my $DEFAULT_MAP_FILE => 'extension_compatibility_table.txt';
Readonly::Scalar my $YES => 'Yes';
Readonly::Scalar my $NO => 'No';

main();

sub main() {
    my %options = get_options();

    my $map_file = $options{'map-file'} || $DEFAULT_MAP_FILE;
    my $map = get_map($map_file);

    print_supported_browsers_and_exit($map) if $options{'list-browsers'};

    push @ARGV, find_js_files();

    # {
    #   browser1 => {
    #     ver => VERSION,
    #     symbol1 => VERSION,
    #     ...
    #   },
    #   ...
    # }
    my $min_ver = create_min_ver_hash($map);

    while (my $line = <<>>) {
        for my $word (words($line)) {
            next unless exists $map->{$word};

            for my $browser (keys %{ $map->{$word} }) {
                my $support = $map->{$word}->{$browser};
                $min_ver->{$browser}->{$word} = $support
                    if $options{verbose};

                my $current_ver = $min_ver->{$browser}->{ver};
                next if $current_ver eq $NO;

                if (looks_like_number($support)) {
                    $min_ver->{$browser}->{ver} = $support
                        if !looks_like_number($current_ver) || $support > $current_ver;
                }
                else {
                    $min_ver->{$browser}->{ver} = $support;
                }
            }
        }
    }

    print_result($min_ver, $options{verbose});
}

sub get_options() {
    my (%options, $help, $version);
    GetOptions(
        'b|browsers=s' => \$options{browsers},
        'h|help' => \$help,
        'l|list-browsers' => \$options{'list-browsers'},
        'm|map=s' => \$options{'map-file'},
        'v|verbose' => \$options{verbose},
        'V|version' => \$version,
    ) || exit 1;

    print_usage_and_exit() if $help;
    print_version_and_exit() if $version;

    return %options;
}

sub print_usage_and_exit() {
    my $program = basename $0;
    print <<HELP;
$program $VERSION
usage: $program [OPTIONS ...] FILE ...

options:
  -b, --browsers BROWSER ...  Find the minimum version of these browsers only.
                              Defaults to all supported browsers
  -h, --help                  Print this help and exit
  -l, --list-browsers         List all supported browsers and exit
  -m, --map FILE              Symbol version lookup table file. Defaults to
                              $DEFAULT_MAP_FILE
  -v, --verbose               Print symbols and their versions
  -V, --version               Print version and exit
HELP

    exit 0;
}

sub print_version_and_exit() {
    say $VERSION;

    exit 0;
}

sub print_supported_browsers_and_exit($map) {
    say join("\n", get_supported_browsers($map));

    exit 0;
}

sub get_supported_browsers($map) {
    return sort keys %{ $map->{ (keys %$map)[0] } };
}

sub get_map($file) {
    open my $fh, '<', $file or die $!;
    undef $/;
    my $map = <$fh>;
    $map =~ s/^\$VAR1 =//;
    
    return eval $map;
}

sub find_js_files() {
    my @js;
    my @dirs = grep { -d } @ARGV;
    @ARGV = grep { -f } @ARGV;

    find({ wanted => sub {
        my $f = $File::Find::name;
        push @js, $f if -f $f && $f =~ /\.js$/;
    }, no_chdir => 1 }, @dirs);

    return @js;
}

sub create_min_ver_hash($map) {
    my $min_ver = {};

    my @browsers = get_supported_browsers($map);
    for my $browser (@browsers) {
        $min_ver->{$browser} = { ver => $YES };
    }

    return $min_ver;
}

sub words($line) {
    my @symbols;

    while ($line =~ /( ([a-z]+ \.) [a-z]+ )/ixg) {
        push @symbols, $1;

        # Start matching from the last word if there's a match.
        pos($line) = $+[2] if length $2;
    }

    return @symbols if @symbols;
}

sub print_result($min_ver, $verbose) {
    my @browsers = sort keys %$min_ver;
    my $longest_browser = find_longest_str(@browsers);

    for my $browser (@browsers) {
        my $indent = $longest_browser - length($browser) + 8;
        printf "$browser%${indent}s\n", $min_ver->{$browser}->{ver};

        if ($verbose) {
            my @symbols = sort keys %{ $min_ver->{$browser} };
            my $longest_symbol = find_longest_str(@symbols);

            for my $symbol (@symbols) {
                next if $symbol eq 'ver';

                my $indent = $longest_symbol - length($symbol) + 8;
                printf "    $symbol%${indent}s\n", $min_ver->{$browser}->{$symbol};
            }
        }
    }
}

sub find_longest_str(@strings) {
    return length(reduce { length $a > length $b ? $a : $b } @strings);
}
