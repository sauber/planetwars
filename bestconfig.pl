#!/usr/bin/perl

# Find the best config option for planetwars bot.
# (C) Soren, 2010-09-23

use warnings;
use strict;

sub x { use Data::Dumper; warn Data::Dumper->Dump([$_[1]], ["*** $_[0]"]); }

our %options = (
  openingmoves  => [qw( 2 4 6 8 10 12 14 16 18 20 )],
  numfleets     => [qw( 100 130 140 150 160 180 )],
  attackbalance => [qw( 2.0 2.5 3.0 4.0 6.0)],
  minfleetsize  => [qw( 6 7 8 9 10 11 12 13 14 15)],
  maxorders     => [qw( 1 2 3 4 )],
  distance      => [qw( 1 2 3 4 5 )],
  ships         => [qw( 1 2 3 4 5 )],
  incoming      => [qw( 1 2 3 4 5 )],
  planetsize    => [qw( 0.2 0.5 0.9 1.0 1.1 1.2 1.5 2 )],
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
    #my @best = 
    #  sort { $score{$k}{$b} <=> $score{$k}{$a} }
    #  keys %{$score{$k}};
    #$b{$k} = shift @best;
    my $count = 0;
    my $sum = 0;
    while ( my($v,$s) = each %{ $score{$k} } ) {
      next if $s <= 0;
      $sum += $v * $s;
      $count += $s;
    }
    $count ||= 1;
    $sum ||= 1;
    my $avg = $sum / $count;
    $b{$k} = sprintf "%.2f", $sum / $count;
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
      'perl MyBot.pl -o $opt1->{openingmoves} -n $opt1->{numfleets} -b $opt1->{attackbalance} -f  $opt1->{minfleetsize} -a $opt1->{maxorders} -d $opt1->{distance} -s $opt1->{ships} -i $opt1->{incoming} -p $opt1->{planetsize}' \\
      'perl MyBot.pl -o $opt2->{openingmoves} -n $opt2->{numfleets} -b $opt2->{attackbalance} -f  $opt2->{minfleetsize} -a $opt2->{maxorders} -d $opt2->{distance} -s $opt2->{ships} -i $opt2->{incoming} -p $opt2->{planetsize}' \\
       2>&1 1>/dev/null 
  };
  return $output;
}

sub updatescore {
  my($opt1,$opt2,$outcome) = @_;
  #warn $outcome;
  my($winner,$looser);
  if ( $outcome =~ /(\d+).Player 1 Wins/s ) {
    warn "Player 1 wins after $1 turns\n";
    $winner = $opt1; $looser = $opt2;
  } elsif ( $outcome =~ /(\d+).Player 2 Wins/s ) {
    warn "Player 2 wins after $1 turns\n";
    $winner = $opt2; $looser = $opt1;
  } else {
    warn "No winner\n";
    return;
  }
  for my $k ( keys %options ) {
    ++$score{$k}{$winner->{$k}};
    --$score{$k}{$looser->{$k}};
  }
}

my %player1 = randomoptions();
my %player2 = randomoptions();
my $outcome = rungame(\%player1, \%player2);
updatescore( \%player1, \%player2, $outcome );
for ( 1..2500 ) {
  my %player1 = randomoptions();
  my %player2 = randomoptions();
  my $outcome = rungame(\%player1, \%player2);
  updatescore( \%player1, \%player2, $outcome );
  x 'bestscore', { bestoptions() };
  #x 'score', \%score;
}
