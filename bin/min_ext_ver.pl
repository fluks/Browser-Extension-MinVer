#!/usr/bin/env perl
use strict;
use warnings;
use feature qw(say signatures);
no warnings 'experimental::signatures';

use Scalar::Util qw(looks_like_number);
use Readonly;
use List::Util qw(reduce);
use Getopt::Long qw(:config bundling no_ignore_case);
use File::Basename;
use File::Find;
use English;
use Cwd qw(abs_path);
use File::ShareDir qw(dist_file);

Readonly::Scalar my $VERSION => '0.2.0';
Readonly::Scalar my $DEFAULT_MAP_FILE =>
    dist_file('Browser-Extension-MinVer', 'extension_compatibility_table.txt');
Readonly::Scalar my $YES => 'Yes';
Readonly::Scalar my $NO => 'No';
Readonly::Scalar my $VERBOSE_SYMBOLS => 0b01;
Readonly::Scalar my $VERBOSE_LINES   => 0b10;

main();

sub main() {
    my %options = get_options();

    my $map_file = $options{'map-file'} || $DEFAULT_MAP_FILE;
    my $map = get_map($map_file);

    print_supported_browsers_and_exit($map) if $options{'list-browsers'};

    $options{browsers} = [ $options{browsers} ?
        parse_browsers_option($options{browsers}, $map) :
        get_supported_browsers($map)
    ];

    push @ARGV, find_js_files();

    my $min_ver = create_min_ver_hash($map);

    my ($file, $line_number) = ('', 0);
    while (my $line = <<>>) {
        update_file_and_line_number(\$file, \$line_number);

        for my $word (words($line)) {
            next unless exists $map->{$word};

            for my $browser (keys %{ $map->{$word} }) {
                my $support = $map->{$word}->{$browser};

                $min_ver->{$browser}->{$word}->{ver} = $support
                    if $options{verbose} & $VERBOSE_SYMBOLS;
                $min_ver->{$browser}->{$word}->{lines}->{$file}->{$line_number} = 1
                    if $options{verbose} & $VERBOSE_LINES;

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

    print_result($min_ver, $options{verbose}, @{ $options{browsers} });
}

sub get_options() {
    my (%options, $help, $version) = ((verbose => 0));
    GetOptions(
        'b|browsers=s' => \$options{browsers},
        'h|help' => \$help,
        'l|list-browsers' => \$options{'list-browsers'},
        'm|map=s' => \$options{'map-file'},
        'v|verbose+' => \$options{verbose},
        'V|version' => \$version,
    ) || exit 1;

    $options{verbose} = verbose2bitfield($options{verbose});

    print_usage_and_exit() if $help;
    print_version_and_exit() if $version;

    return %options;
}

sub parse_browsers_option($argument, $map) {
    my @args = split ',', $argument;
    my @supported_browsers = get_supported_browsers($map);

    my %browsers;
    for my $arg (@args) {
        my @b = grep { /$arg/i } @supported_browsers;
        if (@b > 1) {
            my @equals = grep { /^$arg$/i } @b;
            @b = $equals[0] if @equals == 1;
        }

        die "Browser argument '$arg' doesn't match any browser" if !@b;
        die "Browser argument '$arg' is unambiguous" if @b > 1;

        $browsers{$b[0]} = 1;
    }

    return sort keys %browsers;
}

sub verbose2bitfield($verbosity) {
    return oct('0b'. (1 x $verbosity));
}

sub print_usage_and_exit() {
    my $program = basename $0;
    print <<HELP;
$program $VERSION
usage: $program [OPTIONS ...] FILE ...

options:
  -b, --browsers BROWSER,...  Find the minimum version of these browsers only. Only part of the
                              browser's name is required, as long as it's unambiguous. Separate
                              by commas. Defaults to all supported browsers
  -h, --help                  Print this help and exit
  -l, --list-browsers         List all supported browsers and exit
  -m, --map FILE              Symbol version lookup table file. Defaults to
                              $DEFAULT_MAP_FILE
  -v, --verbose               Print symbols and their versions. More verbose prints lines where
                              the symbols are in FILEs
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
    local $INPUT_RECORD_SEPARATOR = undef;
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

# {
#   browser1 => {
#     ver => VERSION,
#     symbol1 => {
#       ver => VERSION,
#       lines => {
#         file1 => {
#           line_number1 => 1,
#           ...
#         },
#         ...
#       }
#     },
#     ...
#   },
#   ...
# }
sub create_min_ver_hash($map) {
    my $min_ver = {};

    my @browsers = get_supported_browsers($map);
    for my $browser (@browsers) {
        $min_ver->{$browser} = { ver => $YES };
    }

    return $min_ver;
}

sub update_file_and_line_number($file, $line_number) {
    my $new_file = abs_path($ARGV);
    if (!$$file || $$file ne $new_file) {
        $$line_number = 1;
        $$file = $new_file;
    }
    else {
        $$line_number++;
    }
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

sub print_result($min_ver, $verbose, @browsers) {
    my $longest_browser = find_longest_str(@browsers);

    for my $browser (@browsers) {
        my $indent = $longest_browser - length($browser) + 8;
        printf "$browser%${indent}s\n", $min_ver->{$browser}->{ver};

        if ($verbose & $VERBOSE_SYMBOLS) {
            my @symbols = sort keys %{ $min_ver->{$browser} };
            my $longest_symbol = find_longest_str(@symbols);

            for my $symbol (@symbols) {
                next if $symbol eq 'ver';

                my $indent = $longest_symbol - length($symbol) + 8;
                printf ' ' x 4 . "$symbol%${indent}s\n",
                    $min_ver->{$browser}->{$symbol}->{ver};

                if ($verbose & $VERBOSE_LINES) {
                    my @files = sort keys %{ $min_ver->{$browser}->{$symbol}->{lines} };
                    my $longest_file = find_longest_str(@files);

                    for my $file (@files) {
                        my $line_numbers = join(', ',
                            sort { $a <=> $b } keys %{ $min_ver->{$browser}->{$symbol}->{lines}->{$file} });
                        my $indent = $longest_file - length($file) + length($line_numbers) + 4;
                        printf ' ' x 8 . "$file%${indent}s\n", $line_numbers;
                    }
                }
            }
        }
    }
}

sub find_longest_str(@strings) {
    return length(reduce { length $a > length $b ? $a : $b } @strings);
}
