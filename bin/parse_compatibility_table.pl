#!/usr/bin/env perl
use strict;
use warnings;
use feature qw(say signatures);
no warnings 'experimental::signatures';
use Mojo::UserAgent;
use Data::Dumper;

my $url = 'https://developer.mozilla.org/en-US/Add-ons/WebExtensions/Browser_support_for_JavaScript_APIs';
my $dom = Mojo::UserAgent->new->get($url)->res->dom;
my $map = {};

for my $h2 ($dom->find('h2')->each) {
    my $lib = $h2->attr('id');
    next unless $lib;
    my $table = $dom->find("h2[id=$lib] + table")->first;
    next unless $table;

    my @browsers = map { $_->text } $table->find('th')->each;
    next unless @browsers;
    shift @browsers;
    for my $tr ($table->find('tbody > tr')->each) {
        my @tds = $tr->find('td')->each;
        my $symbol = (shift @tds)->children->first->text;
        for (my $i = 0; $i < @tds; $i++) {
            my $child = $tds[$i]->children->first;
            my $support;
            if ($child) {
                $support = $child->text;
            }
            else {
                $support = $tds[$i]->text;
            }
            
            $support =~ s/\W//g;
            $map->{"${lib}.${symbol}"}->{$browsers[$i]} = $support;
        }
    }
}

$Data::Dumper::Sortkeys = 1;
print Dumper $map;
