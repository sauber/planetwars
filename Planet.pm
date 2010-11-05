package Planet;
use strict;
use warnings;

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
    if (defined $new_owner) {
        $self->{_owner} = $new_owner;
    }
    return $self->{_owner}
}

sub NumShips {
    my ($self, $new_num_ships) = @_;
    if (defined $new_num_ships) {
        $self->{_num_ships} = $new_num_ships;
    }
    return $self->{_num_ships}
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

1;
