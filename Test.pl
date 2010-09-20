#!/usr/bin/perl

use feature ':5.10';
use warnings;
use strict;
use PlanetWars;
use Test::More tests => 31;

say "Testing Fleet-object";
my $fleet = new Fleet(0, 1, 2, 3, 4, 5, 6);

is($fleet->FleetID(),0,'FleetID');
is($fleet->Owner(),1,'Owner');
is($fleet->NumShips(),2,'NumShips');
is($fleet->SourcePlanet(),3,'SourcePlanet');
is($fleet->DestinationPlanet(),4,'DestinationPlanet');
is($fleet->TotalTripLength(),5,'TotalTripLength');
is($fleet->TurnsRemaining(),6,'TurnsRemaining');

say "Testing Planet-object";
my $planet = new Planet(0, 1, 2, 1, 4, 5);

is($planet->PlanetID(),0,'PlanetID');
is($planet->X(),1,'X');
is($planet->Y(),2,'Y');
is($planet->Owner(),1,'Owner');
is($planet->NumShips(),4,'NumShips');
is($planet->GrowthRate(),5,'GrowthRate');

$planet->Owner(6);
is($planet->Owner(),6,'New Owner');

$planet->AddShips(7);
is($planet->NumShips(),11,'AddShips');
$planet->RemoveShips(8);
is($planet->NumShips(),3,'RemoveShips');

say "Testing PlanetWars-object";
my $PlanetWars = new PlanetWars(["P 0 0 1 34 2","P 7 9 2 34 2","P 3.14 2.71 0 15 5","F 1 15 0 1 12 2","F 2 28 1 2 8 4"]);

is($PlanetWars->NumPlanets(),3,'NumPlanets');

my @planets = $PlanetWars->Planets();
isa_ok($planets[0],'Planet','Planets');
isa_ok($PlanetWars->GetPlanet(0),'Planet','GetPlanet');

@planets = $PlanetWars->MyPlanets();
is($planets[0]->Owner(),1,'MyPlanets');

@planets = $PlanetWars->NeutralPlanets();
is($planets[0]->Owner(),0,'NeutralPlanets');

@planets = $PlanetWars->EnemyPlanets();
cmp_ok($planets[0]->Owner(),'>',1,'EnemyPlanets');

@planets = $PlanetWars->NotMyPlanets();
cmp_ok($planets[0]->Owner(),'!=',1,'NotMyPlanets');

is($PlanetWars->Distance(0,2),5,'Distance');

is($PlanetWars->IsAlive(1),1,'IsAlive1');
is($PlanetWars->IsAlive(3),0,'IsAlive2');

is($PlanetWars->NumPlanets(),3,'NumPlanets');

my @fleets = $PlanetWars->Fleets();
isa_ok($fleets[0],'Fleet','Fleets');
isa_ok($PlanetWars->GetFleet(0),'Fleet','GetFleet');

@fleets = $PlanetWars->MyFleets();
is($fleets[0]->Owner(),1,'MyFleets');

@fleets = $PlanetWars->EnemyFleets();
cmp_ok($fleets[0]->Owner(),'>',1,'EnemyFleets');

done_testing();
