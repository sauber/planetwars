#!/usr/bin/perl

use warnings;
use strict;
use PlanetWars;
use POSIX;
use Getopt::Std;

# Some ideas to work on:
#  - Make sure all owned planets are not lost by attack
#  - Sacrifice remote if needed
#  - Don't send reinforcement to my planet if not needed
#  - Maximize loss by taken recently conquered neutral planets from opponent
#  - When attacking new planet, do in full force
#  - If a planet is not under attack, send everything it got
#  - When game is already won, stop sending ships
#  - When game is already lost, go to most far away planet
#  - When finding out that enemy is attacking neutral planet, make sure to take over after him to maximize his loss
#  - Make sure each of my planets can withstand takeover attempt from nearest enemy
#  - If my take over is inevitable, stop send more ships
#  - After simulation categorize my planets:
#    * Will loose them - but can prevent
#    * Will loose them - cannot prevent - amount of ships available
#    * Will not loose - amount of ships available
#  - Defend as many as possible
#  - Add remaining to list of planets that will be lost
#  - For remaining planet with available ships
#    * Choose three planets that are most close to most desired enemy/neutral
#    * For each attacker, find nearests hub
#    * All other planets send to nearest hub
#

local $| = 1;
my $map_data;
my $session = {
  move     => 0,
  distance => {},
  config   => {
    openingmoves => 3,  # 1 2 3 4 5
    numfleets => 126, # 10, 25, 50, 75, 100, 150, 200, 300
    attackbalance => 2.28, # 0.0 0.5 0.75 1.0 1.1 1.25 1.5 2.0 3.0 5.0 10.0
    minfleetsize => 20, # 1 2 3 4 5 6 7 8 9 10
    maxorders => 2, # 1 2 3 4 5 6 7 8 9 10
    distance => 4.56, # 0.1 0.2 0.5 0.75 1.0 1.5 2 5 10
    ships => 2.54, # 0.1 0.2 0.5 0.75 1.0 1.5 2 5 10
    incoming => 1.67, # 0.1 0.2 0.5 0.75 1.0 1.5 2 5 10
    planetsize => 0.57, # 0.2 0.5 0.9 1.0 1.1 1.2 1.5 2
  },
};

sub x { use Data::Dumper; warn Data::Dumper->Dump([$_[1]], ["*** $_[0]"]); }

# Read config params from environment
#my %config = @ARGV;
#my($k,$v);
my(%opts);
getopt('onbfadsip', \%opts);
#for my $k ( keys %{$session->{config}} ) {
#  next unless $ENV{$k};
#  $session->{config}{$k} = $ENV{$k};
#}
$session->{config}{openingmoves}  = int $opts{o} if $opts{o};
$session->{config}{numfleets}     = int $opts{n} if $opts{n};
$session->{config}{attackbalance} =     $opts{b} if $opts{b};
$session->{config}{minfleetsize}  = int $opts{f} if $opts{f};
$session->{config}{maxorders}     = int $opts{a} if $opts{a};
$session->{config}{distance}      =     $opts{d} if $opts{d};
$session->{config}{ships}         =     $opts{s} if $opts{s};
$session->{config}{incoming}      =     $opts{i} if $opts{i};
$session->{config}{planetsize}    =     $opts{p} if $opts{p};
#x 'session', $session;
#die;

while(1) {
    my $current_line = <STDIN>;
    next unless defined($current_line);
    if ($current_line =~ /^stop/) {
        last;
    }
    elsif ($current_line =~ m/go/) {
        my $pw = new PlanetWars($map_data);
        ++$session->{move};
        DoTurn($pw,$session);
        $pw->FinishTurn();
        $map_data = [];
    } else {
        push(@$map_data,$current_line);
    }
    last if eof();
}

sub DoTurn {
  my($pw,$session) = @_;

  # First some easy moves
  return unless $pw->MyPlanets;              # No ships available
  return if FirstMove($pw,$session);         # Take nearby planets quickly
  return if AlreadyWon($pw,$session);        # I will win
  return if LastDesperateMove($pw,$session); # Abandon last planet

  # Run simulation
  Simulation($pw,$session);
  #my @defend = LoosingTargets($pw,$session);

  # Defense
  DefendMove($pw,$session);


  # Opening Move
  #if ( $session->{move} <= $session->{config}{openingmoves} ) {
  #  FirstMove($pw,$session);

  # Enough going on already
  if ( $pw->MyFleets() > $session->{config}{numfleets} ) {
    return;

  # I will win

  # Attack to erase opponent
  #} elsif ( Balance($pw) > $session->{config}{attackbalance} ) {
  #} else {
  #  Attack($pw,$session);

  # Growth
  } else {
    Grow($pw,$session);
  }
  # Defensive
  # I will loose
}

# Issue an order to send ships
#
sub SendShips {
  my($pw,$session,$source,$dest,$ships,$reason) = @_;

  warn "Order $session->{move}: $source -> $dest $ships: $reason\n";
  # Check for mistakes
  my $planet = $pw->GetPlanet($source);
  unless ( $planet ) {
    warn sprintf "Error: Planet %s does not exist\n", $source;
    return undef;
  }
  unless ( $pw->GetPlanet($dest) ) {
    warn sprintf "Error: Planet %s does not exist\n", $dest;
    return undef;
  }
  if ( $planet->NumShips < $ships ) {
    warn sprintf "Error: Planet %s only has %s ships\n",
      $source, $planet->NumShips;
    return undef;
  }
  if ( $planet->Owner != 1 ) {
    warn sprintf "Error: Planet %s is not mine\n", $source;
    return undef;
  }
  if ( $ships < 1 ) {
    warn sprintf "Error: Ships %s are less than one\n", $ships;
    return undef;
  }

  $pw->IssueOrder($source, $dest, $ships);
  my $newcount = $planet->NumShips - $ships;
  $planet->NumShips($newcount);
}

sub FirstMove {
  my($pw,$session) = @_;

  return undef if $session->{move} > $session->{config}{openingmoves};

  my $distance = $session->{distance};

  my($myplanet   )= $pw->MyPlanets();
  my $myid        = $myplanet->PlanetID();
  my $numships    = $myplanet->NumShips();

  # Get ranked targets
  my %target = FirstTargets($pw,$session);
  #my %target = DefenseTargets($pw,$session);
  my @moves = RankTargets($pw,$session,$myplanet,%target);
  #x 'firstmoves', \@moves;

  # Send ships to higest desire as long as we have enough ships
  for my $dest ( @moves ) {
    next if $session->{firstsent}{$dest->{planetid}};
    my $tosend = $dest->{planet}->NumShips() +1;
    next if $tosend >= $numships;
    #$pw->IssueOrder($myid,$dest->{planetid}, $tosend);
    SendShips($pw,$session,$myid,$dest->{planetid}, $tosend,'FirstMove');
    $numships -= $tosend;
    ++$session->{firstsent}{$dest->{planetid}};
  }
  return 1;
}

# Last Desperate Move
# I have only one planets left, and it will be taken over.
# Fly ships as far away as possible
# XXX: If there are other ships in flight, go to same destination
# XXX: Prefer planets that I can concur
# XXX: If all my planets will be taken over in next move
#
sub LastDesperateMove {
  my($pw,$session) = @_;

  return undef if $pw->MyPlanets() > 1; # I have more than one planet

  my($myplanet   )= $pw->MyPlanets();
  my $myid        = $myplanet->PlanetID();
  return undef unless $session->{loosing}{$myid}; # I'm not loosing my planet
  return undef unless $session->{loosing}{$myid} == 1; # I'm not loosing in next turn
  warn "Attempting Desperate Move\n";

  # Find Distances to all neutralplanets
  for my $target ( $pw->NeutralPlanets ) {
    my $targetid = $target->PlanetID;
    next if $targetid == $myid;
    $session->{distance}{$myid}{$targetid} ||= $pw->Distance( $myid,$targetid );
  }

  # Find planet most far away
  my $farplanet;
  my $distance = 0;
  for my $target ( keys %{ $session->{distance}{$myid} } ) {
    next if $pw->GetPlanet($target)->Owner > 0 and $pw->NeutralPlanets;
    if ( $session->{distance}{$myid}{$target} > $distance ) {
      $distance = $session->{distance}{$myid}{$target};
      $farplanet = $target;
    }
  }

  return undef unless $farplanet;
  #warn sprintf "Making Desperate move from %s to %s with %s ships\n",
  #  $myid,$farplanet, $myplanet->NumShips;
  #$pw->IssueOrder($myid,$farplanet, $myplanet->NumShips);
  SendShips($pw, $session, $myid, $farplanet, $myplanet->NumShips, 'LastDesperateMove');
  return 1;
}

# If I have no planets pending to be lost, and enemy has no planets that
# he will keep, then stop sending any more ships.
#
sub AlreadyWon {
  my($pw,$session) = @_;

  return undef if $session->{move} < 2;
  # Enemy will keep or concur a planet
  for my $planet ( $pw->Planets ) {
    my $planetid = $planet->PlanetID();
    #warn "Checking planet id $planetid\n";
    return undef if $planet->Owner == 2 and not $session->{simulation}{$planetid};
    if ( my $numships = $session->{simulation}{$planetid} ) {
      #x "Enemy planet $planetid move $#$numships", $numships;
      return undef if $numships->[$#$numships]{owner} == 2;
    }
  }

  # I don't loose any, and he keeps nothing
  #x 'already won', $session->{simulation};
  warn "Already won in move $session->{move}\n";
  return 1;
}

# Defend as much as possible
#
sub DefendMove {
  my($pw,$session) = @_;

  # For all planets that need defense, what is cost of defending.
  my %defend = map { $_ => 1 } LoosingTargets($pw,$session);
  for my $planetid ( keys %defend ) {
    $defend{$planetid} = PlanetRescueCost($pw,$session,$planetid)
  }
  #x 'defense costs', \%defend if %defend;

  # Defend all planets in order of cost
  for my $planetid ( sort { $defend{$a} <=> $defend{$b} } keys %defend ) {
    DefendPlanet($pw,$session,$planetid);
  }

  return undef;
}

# Defend a planet by sending rescue from planets that are close enough
#
sub DefendPlanet {
  my($pw,$session,$planetid) = @_;

  # Make sure all distances are known
  for my $planet ( $pw->MyPlanets ) {
    my $id = $planet->PlanetID;
    $session->{distance}{$planetid}{$id} ||= $pw->Distance($planetid,$id);
  }

  # How soon is rescue required, and how much
  #x "DefendPlanet $planetid", $session->{loosing}{$planetid};
  my $turns = $session->{loosing}{$planetid};
  my $needships = $session->{simulation}{$planetid}[$turns]{numships};
  return undef if $numships <= 0;
  warn "In $turns turns planet $planetid need $needships ships\n";

  # Which planets are within reach
  my @nearby = 
    grep {
      my $id = $_->PlanetID;
      my $dist = $session->{distance}{$planetid}{$id};
      $id != $planetid and
      $dist <= $turns and
      not defined $session->{loosing}{$id};
    }
    $pw->MyPlanets;

  # Check if we can send enough
  my %order;
  for my $planet ( @nearby ) {
    my $sending = ( $planet->NumShips >= $needships )
                ? $needships
                : $planet->NumShips;
    #SendShips($pw, $session, $planet->PlanetID, $planetid, $sending, 'Rescue');
    $order{$planet->PlanetID} = $sending;
    $needships -= $sending;
    last if $needships <= 0;
  }

  if ( $needships <= 0 ) {
    while ( my($source,$sending) = each %order ) {
      SendShips($pw, $session, $source, $planetid, $sending, 'Rescue');
    }
  } else {
    warn "Planet $planetid cannot be rescued\n";
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
  if ( $target{$myid} and $target{$myid}{available} ) {
    $numships = $target{$myid}{available};
  };

  my $minsize = $session->{config}{minfleetsize};
  return unless $numships > $minsize+1;

  my @moves = RankTargets($pw,$session,$myplanet,%target);

  # Tunables
  my $orders = int $numships / $minsize;
  my $maxorders = $session->{config}{maxorders};
  my $send = int $numships / ($maxorders+1);
  $send = $minsize if $send < $minsize;

  for my $dest ( @moves ) {
    #$pw->IssueOrder($myid,$dest->{planetid}, $send);
    SendShips($pw, $session, $myid,$dest->{planetid}, $send, 'SendFleets');
    last if --$orders <= 0;
    last if --$maxorders <= 0;
  }
}

# How attractive it is for one planet to attack another
#   Desire = Growth / ( Distance + Ships + Incoming )
#
sub Desire {
  my($pw,$session,$p1,$p2) = @_;

  my $p1id = $p1->PlanetID();
  my $p2id = $p2->PlanetID();
  my $dist = $session->{distance}{$p1id}{$p2id} ||= $pw->Distance( $p1id,$p2id );
  $dist = $dist ** 1.5;
  my $incoming = $p2->{incoming} || 0;
  return $p2->GrowthRate()**$session->{config}{planetsize} / ( 
    $session->{config}{distance} * $dist          +
    $session->{config}{ships}    *  $p2->NumShips +
    $session->{config}{incoming} *  $incoming
  );
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
  #for my $fl ( $pw->EnemyFleets() ) {
  #  my $planetid = $fl->DestinationPlanet();
  #  $target{$planetid}{planet} ||= $pw->GetPlanet($planetid);
  #  $target{$planetid}{incoming} += $fl->NumShips();
  #}
  my %defense = DefenseTargets($pw);
  while ( my($planetid,$data) = each %defense ) {
    $target{$planetid} = $data;
  }
  return %target;
}

# Enemy and Neutral and Mine under attack
#
sub GrowTargets {
  my $pw = shift;

  my %target = map {( $_->PlanetID() => { planet => $_ } )} 
               $pw->NotMyPlanets();
  #for my $fl ( $pw->EnemyFleets() ) {
  #  my $planetid = $fl->DestinationPlanet();
  #  $target{$planetid}{planet} ||= $pw->GetPlanet($planetid);
  #  $target{$planetid}{incoming} += $fl->NumShips();
  #}

  my %defense = DefenseTargets($pw);
  while ( my($planetid,$data) = each %defense ) {
    $target{$planetid} = $data;
  }
  return %target;
}

# My planets under attack that does not have sufficient defense
#
sub  DefenseTargets {
  my $pw = shift;

  my %target = ();
  my $arrival = 99999;
  for my $fl ( $pw->Fleets() ) {
    my $planetid = $fl->DestinationPlanet();
    $target{$planetid}{planet} ||= $pw->GetPlanet($planetid);
    if ( $fl->Owner() == 1 ) {
      # Reinforcements I already sent
      # XXX That will arrive in time
      #$target{$planetid}{incoming} -= $fl->NumShips();
      push @{ $target{$planetid}{rescue} }, $fl;
    } else {
      # Attacks
      $target{$planetid}{incoming} += $fl->NumShips();
      #push @{ $target{$planetid}{attack} }, $fl;
      $arrival = $fl->TurnsRemaining if $fl->TurnsRemaining < $arrival;
    }
  }

  # Does planet have enough ships to defend itself and surplus to send?
  for my $planetid ( keys %target ) {
    unless ( $target{$planetid}{incoming} ) {
      # Not under attack - phew
      delete $target{$planetid};
      next;
    }
    my $rescue = 0;
    for my $fl ( @{ $target{$planetid}{rescue} } ) {
      $rescue += $fl->NumShips() if $fl->TurnsRemaining < $arrival;
    }
    my $sizeatarrival = $target{$planetid}{planet}->NumShips()
                      + $target{$planetid}{planet}->GrowthRate * $arrival
                      + $rescue;
    $target{$planetid}{available} = $sizeatarrival
                                  - $target{$planetid}{incoming};
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

########################################################################
# DEFENSE
#
# Run simulation of outcome of all fleets
# For all planets that will be lost at some point, calculate the cost
# of rescue.
# Any planets that will be lost in next turn and cannot be rescued later,
# give up and make ships available.
# Rescue as many as possible starting with lowest cost.
# Launch immediately only if needed. Otherwise reserve.
# Any ships not needed for defense or rescue can be used for attack.
#
########################################################################

# Determine if any planets are directly under attack
#
#sub DefenseNeeded {
#  my($pw,$session) = @_;
#
#  # Are there any enemy fleets at all?
#  return undef unless $pw->EnemyFleets();
#
#  # List of planets I own
#  my %planetid;
#  for my $planet ( $pw->MyPlanets() ) {
#    ++$planetid{$planet->PlanetID()};
#  }
#
#  # Are there any enemy fleets towards my planets?
#  for my $fl ( $pw->EnemyFleets() ) {
#    return 1 if $planetid{$fl->DestinationPlanet()};
#  }
#
#  return undef;
#}

# List of Planet that are insufficiently defended
#
#sub PlanetsNeedResuce {
#  my($pw,$session) = @_;
#
#  my %lost;
#  for my $planet ( $pw->MyPlanets() ) {
#    next unless my $turn = PlanetNeedDefense($pw,$session,$planet);
#    $lost{$planet}{battle} = $turn;
#  }
#  return %lost;
#}

# Check if a planet need defense
# Returns number of ships needed in each turn
# Returns undef if no ships are needed
#
#sub PlanetNeedDefense {
#  my($pw,$session,$planet) = @_;
#
#  my $planetid = $planet->PlanetID();
#
#  my @enemy;
#  for my $fl ( $pw->EnemyFleets() ) {
#    push @enemy, $fl if $fl->DestinationPlanet() == $planetid;
#  }
#  return $planet->NumShips() unless @enemy; # No attack
#
#  my @rescue;
#  for my $fl ( $pw->MyFleets() ) {
#    push @rescue, $fl if $fl->DestinationPlanet() == $planetid;
#  }
#
#  # Simulate outcome
#  BattleSimulation($pw,$session,$planet,\@enemy,\@rescue);
#}

# Of the planets that need defense, which ones are actually possible
#
#sub PlanetsDefendable {
#  my($pw,$session,$planet) = @_;
#}

# Check for takeover events for my planets
#
sub LoosingTargets {
  my($pw,$session) = @_;

  my %lost;
  my %kept;
  for my $planet ( $pw->MyPlanets ) {
    my $planetid = $planet->PlanetID();
    if ( my $numships = $session->{simulation}{$planetid} ) {
      for my $turn ( 1 .. $#$numships ) {
        if ( $numships->[$turn]{takeover} ) {
          #warn sprintf "Planet %s will be taken over in %s turns\n", 
          #  $planetid, $turn;
          $lost{$planetid} = $turn;
          next;
        }
      }
    }
    # A cached list of planets not lost
    ++$kept{$planetid} unless $lost{$planetid};
  }


  $session->{loosing} = \%lost;
  $session->{keeping} = \%kept;
  return keys %lost;
}

# Calculate Cost of Rescue on Planet
#
sub PlanetRescueCost {
  my($pw,$session,$planetid) = @_;

  #my %sources;
  #if ( $session->{keeping} ) {
  #  # Only use planets with surplus capacity
  #  %sources = %{ $session->{keeping} };
  #} else {
  #  %sources = %{ $session->{loosing} };
  #  delete $sources{$planetid}; # Cannot send rescue from oneself
  #}

  # For now just the end number of enemy ships it will have after simulation
  if ( my $numships = $session->{simulation}{$planetid} ) {
    #warn sprintf "PlanetRescueCost: planet %s, turns %s, enemy %s\n",
    #  $planetid, $#$numships, $numships->[$#$numships]{numships};
    return $numships->[$#$numships]{numships};
  } else {
    # Planet not simulated
    #warn sprintf "PlanetRescueCost: planet %s, ships %s\n",
    #  $planetid, $pw->GetPlanet($planetid)->NumShips();
    return 0 - $pw->GetPlanet($planetid)->NumShips();
  }
}



########################################################################
### SIMULATION
########################################################################

# Complete Simulation.
# Record outcome of all current fleets attacking planets.
# XXX: Add simulation of all planets that are not target of fleets
#
sub Simulation {
  my($pw,$session) = @_;

  my %arrival;
  # Sum all arrivals
  for my $fl ( $pw->Fleets() ) {
    my $planetid = $fl->DestinationPlanet();
    my $numships = $fl->NumShips();
    my $owner = $fl->Owner();
    my $turn = $fl->TurnsRemaining();
    $numships *= -1 if $owner == 2;
    $arrival{$planetid}[$turn] += $numships;
  }

  # Calculate result in each turn
  my %simulation;
  for my $planetid ( keys %arrival ) {
    my $planet = $pw->GetPlanet($planetid);
    my @numships;
    $numships[0] = {
      owner    => $planet->Owner(),
      numships => $planet->NumShips(),
    };
    my $grow = $planet->GrowthRate();
    for my $n ( 1 .. $#{ $arrival{$planetid} } ) {
      my $prevships = $numships[$n-1]{numships};
      my $prevowner = $numships[$n-1]{owner};
      my $delta = $arrival{$planetid}[$n];

      # Arrival
      if ( $delta ) {
        # Who arrives
        my $arriver = 1;
        if ( $delta < 0 ) {
          # Enemy arrive
          $delta = -$delta;
          $arriver = 2;
        }

        # Arrival to neutral
        if ( $prevowner == 0 ) {
          if ( $prevships >= $delta ) {
            # Failed takeover
            $numships[$n]{owner}    = $prevowner;
            $numships[$n]{numships} = $prevships - $delta;
          } else {
            # Successful takeover
            $numships[$n]{owner}    = $arriver;
            $numships[$n]{numships} = $delta - $prevships;
            $numships[$n]{takeover} = 1;
          }

        # Arrival to already owned planet
        } elsif ( $prevowner == $arriver ) {
          $numships[$n]{owner}    = $prevowner;
          $numships[$n]{numships} = $prevships + $grow;

        # Arrival to not owned planet
        } else {
          if ( $prevships + $grow > $delta ) {
            # Failed takeover
            $numships[$n]{owner}    = $prevowner;
            $numships[$n]{numships} = $prevships + $grow - $delta;
          } else {
            # Successful takeover
            $numships[$n]{owner}    = $arriver;
            $numships[$n]{numships} = $delta - ( $prevships + $grow );
            $numships[$n]{takeover} = 1;
          }
        }

      # No arrival
      } else {
        $numships[$n]{owner}    = $prevowner;
        $numships[$n]{numships} = $prevships;
        $numships[$n]{numships} += $grow if $prevowner > 0;
      } 
    }

    $simulation{$planetid} = \@numships;
  }
  $session->{simulation} = \%simulation;
}
