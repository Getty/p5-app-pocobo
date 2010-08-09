package App::Pocobo::Event::Message;

use Moose;

with qw(
	App::Pocobo::Role::Event
);

has message => (
	isa => 'App::Pocobo::Message',
	is => 'ro',
	required => 1,
);

1;