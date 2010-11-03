package Fleet;
use strict;
use warnings;

sub new {
    my $class = shift;    
    my $self = {
        _fleet_id           => shift,
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
sub FleetID {
    my ($self) = @_;
    return $self->{_fleet_id}
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
sub TotalTripLength {
    my ($self) = @_;
    return $self->{_total_trip_length}
}
sub TurnsRemaining {
    my ($self) = @_;
    return $self->{_turns_remaining}
}

1;
