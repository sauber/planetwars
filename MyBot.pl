#!/usr/bin/perl

use feature ':5.10';
use warnings;
use strict;
use PlanetWars;

my $fleet = new Fleet(1, 2, 3, 4, 5, 6);

say $fleet->Owner();
say $fleet->NumShips();
say $fleet->SourcePlanet();
say $fleet->DestinationPlanet();
say $fleet->TotalTripLenght();
say $fleet->TurnsRemaining();

my $planet = new Planet(1, 2, 3, 4, 5, 6);

say $planet->PlanetID();
say $planet->Owner();
say $planet->NumShips();
say $planet->GrowthRate();
say $planet->X();
say $planet->Y();

$planet->Owner(5);
say $planet->Owner();
$planet->Owner(8);
say $planet->Owner();


$planet->AddShips(10);

say $planet->NumShips();

$planet->RemoveShips(8);

say $planet->NumShips();

my $PlanetWars = new PlanetWars();
