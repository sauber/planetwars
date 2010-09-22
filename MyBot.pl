#!/usr/bin/perl

use warnings;
use strict;
use PlanetWars;
use POSIX;

local $| = 1;
my $map_data;
my $distances;
my $closest;

sub x {
 use Data::Dumper;
 warn Data::Dumper->Dump([$_[1]], ["*** $_[0]"]);
}


while(1) {
    my $current_line = <STDIN>;
    if ($current_line =~ m/go/) {
        my $pw = new PlanetWars($map_data);
        unless ( $distances ) {
          $distances = CalcDistances($pw);
          $closest = OrderNeighbors($pw, $distances);
        }
        DoTurn($pw, $distances, $closest);
        $pw->FinishTurn();
        $map_data = [];
    } elsif ($current_line eq "stop\n") {
        last;
    } else {
        push(@$map_data,$current_line);
    }
}
sub DoTurn {
    my ($pw,$distance,$neighbor) = @_;

    # Just send to closest for now
    SendToClosest($pw,$distance,$neighbor);
    return;

      # (1) If we currently have a fleet in flight, just do nothing.
    #if ($pw->MyFleets() > 0) {
    #    return
    #}

      # (2) Find my strongest planet.
    my $source = -1;
    my $source_score = -999999.0;
    my $source_num_ships = 0;
    my @my_planets = $pw->MyPlanets();
    foreach (@my_planets) {
        #my $score = $_->NumShips();
        my $score = $_->NumShips() / ( 1 + $_->GrowthRate() );
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
        #my $score = 1 / (1 + $_->NumShips());
        my $score = (1 + $_->GrowthRate() ) / $_->NumShips();
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

# Send fleets to closest planets
#
sub SendToClosest {
  my($pw,$distance,$neighbor) = @_;

  # Send 6 ships to closet planet that is not mine
  my %not_my_planets = map {( $_->PlanetID() => 1 )} $pw->NotMyPlanets();
  for my $myplanet ( $pw->MyPlanets() ) {
    next unless $myplanet->NumShips() > 6;
    my $myplanetid = $myplanet->PlanetID();
    for my $neighbor ( @{ $neighbor->{$myplanetid} } ) {
      my $neighborid = $neighbor->PlanetID();
      next unless $not_my_planets{$neighborid};
      $pw->IssueOrder($myplanetid,$neighborid, int($myplanet->NumShips()/2) );
      last;
    }
  }
}

sub CalcDistances {
  my($pw) = @_;
  my $distance;

  my $count = 0;
  my @planetids = map $_->PlanetID(), $pw->Planets;
  for my $p1 ( @planetids ) {
    for my $p2 ( @planetids ) {
      next if $p1 == $p2;
      my @index = sort { $a <=> $b } ( $p1, $p2 );
      #$distance->{$index[0]}{$index[1]} ||= $pw->Distance( @index );
      next if $distance->{$index[0]}{$index[1]};
      $distance->{$index[0]}{$index[1]} = $pw->Distance( @index );
      ++$count;
    }
  }
  warn sprintf "There are %s planets and %s distances\n", scalar( $pw->Planets ), $count;
  #x 'distance', $distance;
  return $distance;
}

sub OrderNeighbors {
  my($pw, $distance) = @_;
  my $neighbor;
  #my @planetids = map $_->PlanetID(), $pw->Planets;

  #x 'distance', $distance;

  for my $p1 ( $pw->Planets ) {
    my @order = 
      map $_->[0],
      sort { $a->[1] <=> $b->[1] }
      map {
        # Find distance to each planet
        my @index = sort { $a <=> $b } ( $p1->PlanetID(), $_->PlanetID() );
        my $dist = $distance->{$index[0]}{$index[1]};
        #warn sprintf "Distance between %s and %s is %s\n", @index, $dist;
        [ $_, $dist ];
      }
      grep { $p1->PlanetID() != $_->PlanetID }
      $pw->Planets;
      #@planetids;
    $neighbor->{$p1->PlanetID()} = \@order;
  }
  return $neighbor;
}
