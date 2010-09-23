#!/usr/bin/perl

# Find the best config option for planetwars bot.
# (C) Soren, 2010-09-23

use warnings;
use strict;

sub x { use Data::Dumper; warn Data::Dumper->Dump([$_[1]], ["*** $_[0]"]); }

our %options = (
  openingmoves  => [qw( 2 3 )],
  numfleets     => [qw( 50 75 100 150 200 300 )],
  attackbalance => [qw( 1.0 1.1 1.25 1.5 2.0 3.0 5.0 10.0)],
  minfleetsize  => [qw( 6 7 8 9 10 11 12 13 14 15)],
  maxorders     => [qw(1 2 3 4 )],
);

our %score;

sub randomoptions {
  map {
    $_ => $options{$_}[ rand scalar @{$options{$_}} ]
  } keys %options;
}

sub bestoptions {
  my %b;
  for my $k ( keys %options ) {
    my @best = 
    sort { $score{$k}{$b} <=> $score{$k}{$a} }
    keys %{$score{$k}};
 
    $b{$k} = shift @best;
  }
  %b;
}

sub rungame {
  my($opt1,$opt2) = @_;
  my $map = 1 + int rand 100;
  my $output = qx{
    java -jar ../java_starter_package/tools/PlayGame.jar \\
      ../java_starter_package/maps/map$map.txt \\
      1000 200 log.txt \\
      'perl MyBot.pl -o $opt1->{openingmoves} -n $opt1->{numfleets} -b $opt1->{attackbalance} -f  $opt1->{minfleetsize} -a $opt1->{maxorders}' \\
      'perl MyBot.pl -o $opt2->{openingmoves} -n $opt2->{numfleets} -b $opt2->{attackbalance} -f  $opt2->{minfleetsize} -a $opt2->{maxorders}' \\
       2>&1 1>/dev/null 
  };
  return $output;
}

sub updatescore {
  my($opt1,$opt2,$outcome) = @_;
  my($winner,$looser);
  if ( $outcome =~ /Player 1 Wins/ ) {
    $winner = $opt1; $looser = $opt2;
  } elsif ( $outcome =~ /Player 2 Wins/ ) {
    $winner = $opt2; $looser = $opt1;
  }
  if ( $winner and $looser ) {
    for my $k ( keys %options ) {
      ++$score{$k}{$winner->{$k}};
      --$score{$k}{$looser->{$k}};
    }
  }
}

for ( 1..2500 ) {
  my %player1 = randomoptions();
  my %player2 = randomoptions();
  my $outcome = rungame(\%player1, \%player2);
  updatescore( \%player1, \%player2, $outcome );
  x 'score', \%score;
}
