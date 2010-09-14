#!/usr/bin/perl

use feature ':5.10';
use warnings;
use strict;
use PlanetWars;
use POSIX;

local $| = 1;
my $map_data;

while(1) {
    my $current_line = <STDIN>;
    if ($current_line =~ m/go/) {
        my $pw = new PlanetWars($map_data);
        DoTurn($pw);
        $pw->FinishTurn();
        $map_data = [];
    } elsif ($current_line eq "stop\n") {
        last;
    } else {
        push(@$map_data,$current_line);
    }
}

sub DoTurn {
    my ($pw) = @_;

      # (1) If we currently have a fleet in flight, just do nothing.
    if ($pw->MyFleets() > 0) {
        return
    }

      # (2) Find my strongest planet.
    my $source = -1;
    my $source_score = -999999.0;
    my $source_num_ships = 0;
    my @my_planets = $pw->MyPlanets();
    foreach (@my_planets) {
        my $score = $_->NumShips();
        if ($score > $source_score) {      
            $source_score = $score;
            $source = $_->PlanetID();
            $source_num_ships = $_->NumShips();
        }
    }

      # (3) Find the weakest enemy or neutral planet.
    my $dest = -1;
    my $dest_score = -999999.0;
    my @not_my_planets = $pw->NotMyPlanets();
    foreach (@not_my_planets) {
        my $score = 1 / (1 + $_->NumShips());
        if ($score > $dest_score) {
            $dest_score = $score;
            $dest = $_->PlanetID();
        }
    }

  # (4) Send half the ships from my strongest planet to the weakest planet that I do not own.
    if (($source >= 0) and ($dest >= 0)) {
        my $num_ships = $source_num_ships / 2;
        $pw->IssueOrder($source,$dest,ceil($num_ships));
    }
}





