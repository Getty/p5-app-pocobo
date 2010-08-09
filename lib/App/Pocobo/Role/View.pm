package App::Pocobo::Role::View;

use Moose::Role;

requires 'new_event';
requires 'new_event_cached';

with qw(
	App::Pocobo::Role::Pocobo
);

1;