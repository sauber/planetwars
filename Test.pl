#!/usr/bin/perl

use feature ':5.10';
use warnings;
use strict;
use PlanetWars;
use Test::More;
use Data::Dump;


say "Testing Fleet-object";
my $fleet = new Fleet(1, 2, 3, 4, 5, 6);

is($fleet->Owner(),1,'Owner');
is($fleet->NumShips(),2,'NumShips');
is($fleet->SourcePlanet(),3,'SourcePlanet');
is($fleet->DestinationPlanet(),4,'DestinationPlanet');
is($fleet->TotalTripLenght(),5,'TotalTripLenght');
is($fleet->TurnsRemaining(),6,'TurnsRemaining');

say "Testing Planet-object";
my $planet = new Planet(1, 2, 3, 4, 5, 6);

is($planet->PlanetID(),1,'PlanetID');
is($planet->X(),2,'X');
is($planet->Y(),3,'Y');
is($planet->Owner(),4,'Owner');
is($planet->NumShips(),5,'NumShips');
is($planet->GrowthRate(),6,'GrowthRate');


$planet->Owner(7);
is($planet->Owner(),7,'New Owner');

$planet->AddShips(8);
is($planet->NumShips(),13,'AddShips');
$planet->RemoveShips(9);
is($planet->NumShips(),4,'RemoveShips');

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

#F 1 15 0 1 12 2     # Player one has sent some ships to attack player two.
#F 2 28 1 2  8 4     # Player two has sent some ships to take over the neutral planet.
#go
    