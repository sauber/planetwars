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
  #if ( $session->{move} == 1 ) {
    FirstMove($pw,$session);
  # I will win

  # Attack to erase opponent
  #} elsif ( Balance($pw) > 1 ) {
  #} else {
  #  Attack($pw,$session);

  # Growth
  #} else {
  #  Grow($pw,$session);
  #}
  # Defensive
  # I will loose
}

sub FirstMove {
  my($pw,$session) = @_;
  my $distance = $session->{distance};

  my($myplanet   )= $pw->MyPlanets();
  my $myid        = $myplanet->PlanetID();
  my $numships    = $myplanet->NumShips();

  # Get ranked targets
  my %target = FirstTargets($pw,$session);
  my @moves = RankTargets($pw,$session,$myplanet,%target);
  #x 'firstmoves', \@moves;

  # Send ships to higest desire as long as we have enough ships
  for my $dest ( @moves ) {
    my $tosend = $dest->{numships}+1;
    next if $tosend >= $numships;
    $pw->IssueOrder($myid,$dest->{planetid}, $tosend);
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

sub Attack {
  my($pw,$session) = @_;

  # Targets
  my %target = AttackTargets($pw,$session);

  # Check what each planet can attack
  for my $myplanet ( $pw->MyPlanets() ) {
    my $myid        = $myplanet->PlanetID();
    my $numships    = $myplanet->NumShips();

    # Get ranked targets
    my @moves = RankTargets($pw,$session,$myplanet,%target);

    # Send ships to higest desire as long as we have enough ships
    for my $dest ( @moves ) {
      my $tosend = $dest->{numships}+1;
      next if $tosend >= $numships;
      $pw->IssueOrder($myid,$dest->{planetid}, $tosend);
      $numships -= $tosend;
    }
    last;
  }
}

# How attractive it is for one planet to attack another
#   Desire = Growth / ( Distance + Ships )
#
sub Desire {
  my($pw,$session,$p1,$p2) = @_;

  my $p1id = $p1->PlanetID();
  my $p2id = $p2->PlanetID();
  my $dist = $session->{distance}{$p1id}{$p2id} ||= $pw->Distance( $p1,$p2 );
  return $p2->GrowthRate / ( $dist + $p2->NumShips );
}

# Rank all targets by desire from one planet
#
sub RankTargets {
  my($pw,$session,$myplanet,%target) = @_;

  while ( my($id,$dest) = each %target ) {
    my $planet = $dest->{planet};
    $dest->{desire}   = Desire($pw,$session,$myplanet,$planet);
    $dest->{numships} = $planet->NumShips();
    $dest->{planetid} = $id;
   }
  return map $target{$_}, sort { $target{$b}{desire} <=> $target{$a}{desire} } keys %target;
}

# Neutral planets closer to me than to enemy
#
sub FirstTargets {
  my($pw,$session) = @_;

  my $distance = $session->{distance};
  my($myplanet   )= $pw->MyPlanets();
  my $myid        = $myplanet->PlanetID();
  my($enemyplanet)= $pw->EnemyPlanets();
  my $enemyid     = $enemyplanet->PlanetID();

  my %target = map {( $_->PlanetID() => { planet => $_ } )} 
               $pw->NeutralPlanets();
  for my $dest ( keys %target ) {
    my $mydist    =
      $distance->{$myid}{$dest} ||= $pw->Distance( $myid, $dest );
    my $enemydist =
      $distance->{$enemyid}{$dest} ||= $pw->Distance( $enemyid, $dest );
    delete $target{$dest} if $mydist >= $enemydist;
  }
  return %target;
}

# Enemy planets and planets under attack by enemy
#
sub AttackTargets {
  my $pw = shift;

  my %target = map {( $_->PlanetID() => { planet => $_ } )} 
               $pw->EnemyPlanets();
  for my $fl ( $pw->EnemyFleets() ) {
    my $planetid = $fl->DestinationPlanet();
    $target{$planetid}{planet} ||= $pw->GetPlanet($planetid);
  }
  return %target;
}

# Enemy and Neutral and Mine under attack
#
sub GrowTargets {
  my $pw = shift;

  my %target = map {( $_->PlanetID() => { planet => $_ } )} 
               $pw->NoMyPlanets();
  for my $fl ( $pw->EnemyFleets() ) {
    my $planetid = $fl->DestinationPlanet();
    $target{$planetid}{planet} ||= $pw->GetPlanet($planetid);
  }
  return %target;
}

# How much ahead/behind am I. behind < 1 < ahead
#
sub Balance {
  my($pw) = @_;

  my $myships = 0;
  my $mygrowth = 0;
  for my $planet ( $pw->MyPlanets() ) {
    $myships += $planet->NumShips();
    $mygrowth += $planet->GrowthRate();
  }

  my $enemyships = 0;
  my $enemygrowth = 0;
  for my $planet ( $pw->EnemyPlanets() ) {
    $enemyships += $planet->NumShips();
    $enemygrowth += $planet->GrowthRate();
  }

  return ( $myships/$enemyships + $mygrowth/$enemygrowth ) / 2;
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
