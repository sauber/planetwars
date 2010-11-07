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
    last if eof();
}

sub DoTurn {
  my($pw,$session) = @_;

  # Opening Move
  if ( $session->{move} == 1 ) {
    FirstMove($pw,$session);

   # Enough going on already
   #} elsif ( $pw->MyFleets() > 10 ) {
   #  return;

  # I will win

  # Attack to erase opponent
  } elsif ( Balance($pw) > 1.50 ) {
  #} else {
    Attack($pw,$session);

  # Growth
  } else {
    Grow($pw,$session);
  }
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
    my $tosend = $dest->{planet}->NumShips() +1;
    next if $tosend >= $numships;
    $pw->IssueOrder($myid,$dest->{planetid}, $tosend);
    $numships -= $tosend;
  }
}

# Send fleets to closest planets
#
sub Grow {
  my($pw,$session) = @_;

  my %target = GrowTargets($pw);
  for my $myplanet ( $pw->MyPlanets() ) {
    SendFleets($pw,$session,$myplanet,%target);
  }
}

sub Attack {
  my($pw,$session) = @_;

  my %target = AttackTargets($pw,$session);
  for my $myplanet ( $pw->MyPlanets() ) {
    SendFleets($pw,$session,$myplanet,%target);
  }
}

# Send ships from a source planet to a number of targets
sub SendFleets {
  my($pw,$session,$myplanet,%target) = @_;

  my $myid        = $myplanet->PlanetID();
  my $numships    = $myplanet->NumShips();

  # Don't send ships if I'm under attack and don't have enough defense
  if ( $target{$myid} and $target{$myid}{incoming} ) {
    $numships -= $target{$myid}{incoming};
  };

  my $minsize = 6;
  return unless $numships > $minsize+1;

  my @moves = RankTargets($pw,$session,$myplanet,%target);

  # Tunables
  my $orders = int $numships / $minsize;
  my $maxorders = 4;
  my $send = int $numships / ($maxorders+1);
  $send = $minsize if $send < $minsize;

  for my $dest ( @moves ) {
    $pw->IssueOrder($myid,$dest->{planetid}, $send);
    last if --$orders == 0;
    last if --$maxorders == 0;
  }
}

# How attractive it is for one planet to attack another
#   Desire = Growth / ( Distance + Ships )
#
sub Desire {
  my($pw,$session,$p1,$p2) = @_;

  my $p1id = $p1->PlanetID();
  my $p2id = $p2->PlanetID();
  my $dist = $session->{distance}{$p1id}{$p2id} ||= $pw->Distance( $p1id,$p2id );
  my $incoming = $p2->{incoming} || 0;
  return $p2->GrowthRate()**1.0 / ( $dist + $p2->NumShips + $incoming );
}

# Rank all targets by desire from one planet
#
sub RankTargets {
  my($pw,$session,$myplanet,%target) = @_;

  while ( my($id,$dest) = each %target ) {
    if ( $id == $myplanet->PlanetID() ) {
      # Remove option to send ships to ourselves
      delete $target{$id};
      next;
    }
    my $planet = $dest->{planet};
    $dest->{desire}   = Desire($pw,$session,$myplanet,$planet);
    #$dest->{numships} = $planet->NumShips();
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
    $target{$planetid}{incoming} += $fl->NumShips();
  }
  return %target;
}

# Enemy and Neutral and Mine under attack
#
sub GrowTargets {
  my $pw = shift;

  my %target = map {( $_->PlanetID() => { planet => $_ } )} 
               $pw->NotMyPlanets();
  for my $fl ( $pw->EnemyFleets() ) {
    my $planetid = $fl->DestinationPlanet();
    $target{$planetid}{planet} ||= $pw->GetPlanet($planetid);
    $target{$planetid}{incoming} += $fl->NumShips();
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
  for my $fl ( $pw->MyFleets() ) {
    $myships += $fl->NumShips();
  }

  my $enemyships = 0;
  my $enemygrowth = 0;
  for my $planet ( $pw->EnemyPlanets() ) {
    $enemyships += $planet->NumShips();
    $enemygrowth += $planet->GrowthRate();
  }
  for my $fl ( $pw->EnemyFleets() ) {
    $enemyships += $fl->NumShips();
  }

  return 100 unless $enemyships and $enemygrowth;
  return ( $myships/$enemyships + $mygrowth/$enemygrowth ) / 2;
}
