#!/usr/bin/perl

use feature ':5.10';
use warnings;
use strict;
use POSIX;
use Data::Dump;

package Fleet;
sub new {
    my $class = shift;    
    my $self = {
        _owner              => shift,
        _num_ships          => shift,
        _source_planet      => shift,
        _destination_planet => shift,
        _total_trip_length  => shift,
        _turns_remaining    => shift,
    };    
    bless $self, $class;
    return $self;    
}      
sub Owner {
    my ($self) = @_;
    return $self->{_owner}
}
sub NumShips {
    my ($self) = @_;
    return $self->{_num_ships}
}
sub SourcePlanet {
    my ($self) = @_;
    return $self->{_source_planet}
}
sub DestinationPlanet {
    my ($self) = @_;
    return $self->{_destination_planet}
}
sub TotalTripLenght {
    my ($self) = @_;
    return $self->{_total_trip_length}
}
sub TurnsRemaining {
    my ($self) = @_;
    return $self->{_turns_remaining}
}

package Planet;
sub new {
    my $class = shift;    
    my $self = {
        _planet_id     => shift,
        _X             => shift,
        _Y             => shift,
        _owner         => shift,
        _num_ships     => shift,
        _growth_rate   => shift,

    };    
    bless $self, $class;
    return $self;    
}
sub PlanetID {
    my ($self) = @_;
    return $self->{_planet_id}
}
sub Owner {
    my ($self, $new_owner) = @_;
    unless ($new_owner) {
        return $self->{_owner}
    }
    $self->{_owner} = $new_owner;
}
sub NumShips {
    my ($self, $new_num_ships) = @_;
    unless ($new_num_ships) {
        return $self->{_num_ships}
    }
    $self->{_num_ships} = $new_num_ships;
}
sub GrowthRate {
    my ($self) = @_;
    return $self->{_growth_rate}
}
sub X {
    my ($self) = @_;
    return $self->{_X}
}
sub Y {
    my ($self) = @_;
    return $self->{_Y}
}
sub AddShips {
    my ($self, $amount) = @_;
    $self->{_num_ships} += $amount;
}
sub RemoveShips {
    my ($self, $amount) = @_;
    $self->{_num_ships} -= $amount;
}

package PlanetWars;
sub new {
    my ($class, $gameState) = @_;    
    my $self = {
        _planets => [],
        _fleets  => [],   
    };    
    bless $self, $class;
    $self->ParseGameState($gameState);
    return $self;    
}

sub NumPlanets {
    my ($self) = @_;
    return scalar(@{$self->{_planets}});
}

sub GetPlanet {
    my ($self, $planet_id) = @_;
    foreach (@{$self->{_planets}}) {
        if ($_->PlanetID() == $planet_id) {
            return $_;
        }
    }
    die('planet doesnt exist');
}

sub NumFleets {
    my ($self) = @_;
}

sub GetFleet {
    my ($self) = @_;
}

sub Planets {
    my ($self) = @_;
    return @{$self->{_planets}};
}

sub MyPlanets {
    my ($self) = @_;
    my @planets;
    foreach (@{$self->{_planets}}) {
        if ($_->Owner() == 1) {
            push(@planets,$_);
        }
    }
    return @planets;
}

sub NeutralPlanets {
    my ($self) = @_;
    my @planets;
    foreach (@{$self->{_planets}}) {
        if ($_->Owner() == 0) {
            push(@planets,$_);
        }
    }
    return @planets;
}

sub EnemyPlanets {
    my ($self) = @_;
    my @planets;
    foreach (@{$self->{_planets}}) {
        if (($_->Owner() > 1) ) {
            push(@planets,$_);
        }
    }
    return @planets;
}

sub NotMyPlanets {
    my ($self) = @_;
    my @planets;
    foreach (@{$self->{_planets}}) {
        if ($_->Owner() != 1) {
            push(@planets,$_);
        }
    }
    return @planets;
}

sub MyFleets {
    my ($self) = @_;
}

sub EnemyFleets {
    my ($self) = @_;
}

sub Distance {
    my ($self, $source_planet_id, $destination_planet_id) = @_;
    my $source_planet = $self->GetPlanet($source_planet_id);
    my $destination_planet = $self->GetPlanet($destination_planet_id);
    my $dx = $source_planet->X() - $destination_planet->X();
    my $dy = $source_planet->Y() - $destination_planet->Y();
    return abs(&POSIX::ceil(sqrt($dx * $dx + $dy * $dy)));
}

sub IssueOrder {
    my ($self, $source_planet, $destination_planet, $num_ships) = @_;
    say "$source_planet $destination_planet $num_ships";
}

sub IsAlive {
    my ($self) = @_;
}

sub ParseGameState{
    my ($self, $gameState) = @_;
    my $planet_count = 0;
    my $fleet_count = 0;

    foreach (@$gameState) {
        if ($_ =~ m/P\s(\S+)\s(\S+)\s(\S+)\s(\S+)\s(\S+)/) {;
            push(@{$self->{_planets}},new Planet($planet_count,$1,$2,$3,$4,$5));
            $planet_count++;
        } elsif ($_ =~ m/F\s(\S+)\s(\S+)\s(\S+)\s(\S+)\s(\S+)\s(\S+)/) {
            push(@{$self->{_fleetss}},new Planet($fleet_count,$1,$2,$3,$4,$5,$6));
            $fleet_count++;
        } else {
            die('invalid parseinput')
        };
    }
}

    


sub FinishTurn{
    my ($self) = @_;
}

1;
