package App::Pocobo::Role::Event;

use Moose::Role;
use DateTime;

has from => (
#	isa => 'App::Pocobo::Role::Controller',
	is => 'ro',
	required => 1,
);

sub net {
	my $self = shift;
	$self->from->net;
}

has created => (
	isa => 'DateTime',
	is => 'ro',
	required => 1,
	default => sub { DateTime->now },
);

1;