#!/usr/bin/perl

use warnings;
use strict;
use PlanetWars;
use POSIX;

# Some ideas to work on:
#  - In first move take as many desired planets closeby as possible
#  - 100% defensive will surely loose
#  - Limit number of ships in flight
#  - When having more ships and growth than opponent, attack harder to finish fast
#  - When game is already won, stop sending ships
#  - When game is already lost, go to most far away planet

local $| = 1;
my $map_data;
my $session = {
  distance => {},
  move     => 0,
};

sub x {
 use Data::Dumper;
 warn Data::Dumper->Dump([$_[1]], ["*** $_[0]"]);
}


while(1) {
    my $current_line = <STDIN>;
    if ($current_line =~ m/go/) {
        my $pw = new PlanetWars($map_data);
        ++$session->{move};
        DoTurn($pw,$session);
        $pw->FinishTurn();
        $map_data = [];
    } elsif ($current_line eq "stop\n") {
        last;
    } else {
        push(@$map_data,$current_line);
    }
}
sub old_DoTurn {
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

sub DoTurn {
  my($pw,$session) = @_;

  # Opening Move
  if ( $session->{move} == 1 ) {
    FirstMove($pw,$session);
  # I will win
  # Attack to erase opponent
  # Growth
  # Defensive
  # I will loose

  } else {
    Grow($pw,$session);
  }
}

sub FirstMove {
  my($pw,$session) = @_;
  my $distance = $session->{distance};

  my($myplanet   )= $pw->MyPlanets();
  my $myid        = $myplanet->PlanetID();
  my($enemyplanet)= $pw->EnemyPlanets();
  my $enemyid     = $enemyplanet->PlanetID();
  my $numships    = $myplanet->NumShips();

  # Find target closer to me than to enemy
  my %target = Targets($pw);
  for my $dest ( keys %target ) {
    my $mydist    =
      $distance->{$myid}{$dest} ||= $pw->Distance( $myid, $dest );
    my $enemydist =
      $distance->{$enemyid}{$dest} ||= $pw->Distance( $enemyid, $dest );
    if ( $mydist < $enemydist ) {
      # If closer to me than to enemy, determine the desire
      my $planet = $pw->GetPlanet($dest);
      my $numships = $planet->NumShips();
      my $desire = $planet->GrowthRate() / ( $mydist + $numships );
      $target{$dest} = { 
        desire => $desire,
        numships => $numships,
      };
    } else {
      delete $target{$dest};
    }
  }

  # Send ships to higest desire as long as we have enough ships
  for my $dest ( sort { $target{$b}{desire} <=> $target{$a}{desire} }
                 keys %target ) {
    my $tosend = $target{$dest}{numships}+1;
    next if $tosend >= $numships;
    $pw->IssueOrder($myid,$dest, $tosend);
    $numships -= $tosend;
  }
}

# Send fleets to closest planets
#
sub Grow {
  my($pw,$session) = @_;

  my %target = Targets($pw);
  my $distance = $session->{distance};

  my $minsize = 6;
  for my $myplanet ( $pw->MyPlanets() ) {
    next unless $myplanet->NumShips() > $minsize+1;
    my $myid = $myplanet->PlanetID();
    next if $target{$myid}; # Don't send if under attack

    # Calc distances that has not been calculated before
    #for my $dest ( keys %target ) {
    #  $distance->{$myid}{$dest} ||= $pw->Distance( $myid, $dest );
    #}

    # Don't sent to targets that has enough ships to defend

    # Sort targets by 
    #   1 XXX: Under attack
    #   2 growthrate / ( distance * ships + 1 )
    for my $dest ( keys %target ) {
      my $planet = $pw->GetPlanet($dest);
      my $dist = $distance->{$myid}{$dest} ||= $pw->Distance( $myid, $dest );
      $target{$dest} = $planet->GrowthRate() / ( $dist * ( $planet->NumShips() + 10 ) );
    }

    # Tunables
    my $orders = int $myplanet->NumShips() / $minsize;
    my $maxorders = 4;
    my $send = int $myplanet->NumShips() / ($maxorders+1);
    $send = $minsize if $send < $minsize;

    # XXX: sort by how hard to get
    #for my $neighbor ( @{ $neighbor->{$myid} } ) {
    for my $neighborid ( sort { $target{$b} <=> $target{$a} } keys %target ) {
      #my $neighborid = $neighbor->PlanetID();
      #next unless $target{$neighborid};
      #my $send = int($myplanet->NumShips()/($maxorders+1));
      $pw->IssueOrder($myid,$neighborid, $send);
      #last;
      last if --$orders == 0;
      last if --$maxorders == 0;
    }
  }
}
# List of planets that are
#  - not mine
#  - mine under attack
#
sub Targets {
  my $pw = shift;

  # Targets are planets that are not mine, or mine that are attacked
  my %target = map {( $_->PlanetID() => 1 )} $pw->NotMyPlanets();
  for my $fl ( $pw->EnemyFleets() ) {
    #next if $fl->Owner() == 1;
    #my $planetid = $fl->DestinationPlanet()->PlanetID();
    my $planetid = $fl->DestinationPlanet();
    #my $planetid = 1;
    $target{$planetid} = 1;
  }
  return %target;
}

sub old_CalcDistances {
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

sub old_OrderNeighbors {
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
        my $desire = int $dist / $_->GrowthRate();
        #warn sprintf "Distance between %s and %s is %s\n", @index, $dist;
        [ $_, $desire ];
      }
      grep { $p1->PlanetID() != $_->PlanetID }
      $pw->Planets;
      #@planetids;
    $neighbor->{$p1->PlanetID()} = \@order;
  }
  return $neighbor;
}
