package App::Pocobo::View::IRC;

use 5.010;
use MooseX::POE;
use POE qw(
	Component::Server::TCP
	Filter::Stackable
	Filter::Line
	Filter::IRCD
);

with qw(
	MooseX::LogDispatch
	App::Pocobo::Role::View
);

# debugging rulez
use Data::Dumper;

our $VERSION = '0.001';

has net_map => (
	isa => 'HashRef',
	is => 'rw',
	required => 1,
	default => sub {{}},
);

has tcpheaps => (
	traits     => ['Array'],
	is         => 'ro',
	isa        => 'ArrayRef[HashRef]',
	default    => sub { [] },
	handles    => {
		all_tcpheaps    => 'elements',
		add_tcpheap     => 'push',
	},
);

has strftime => (
	isa => 'Str',
	is => 'rw',
	required => 1,
	default => sub { '%H:%M:%S %d.%m.%y' },
);

has password => (
	isa => 'Str',
	is => 'rw',
	required => 1,
	default => sub { 'setone' },
);

has alias => (
	isa => 'Str',
	is => 'rw',
	required => 1,
	default => sub {
		my $self = shift;
		$self->name.'_view_irc'
	},
);

has ip => (
	isa => 'Str',
	is => 'rw',
	required => 1,
	default => sub { '0.0.0.0' },
);

has port => (
	isa => 'Int',
	is => 'rw',
	required => 1,
	default => sub { 50505 },
);

has name => (
	isa => 'Str',
	is => 'rw',
	required => 1,
	default => sub {
		my @parts = split('::',__PACKAGE__);
		$parts[1];
	},
);

has server_version => (
	isa => 'Str',
	is => 'rw',
	required => 1,
	default => sub { __PACKAGE__.'-'.$VERSION }
);

has server_host => (
	isa => 'Str',
	is => 'rw',
	required => 1,
	default => sub {
		my @parts = split('::',__PACKAGE__);
		# doesnt look so cool
		# push @parts, split('\.',$VERSION);
		my @newparts;
		for (@parts) {
			push @newparts, lc($_);
		}
		join('.',reverse @newparts);
	},
);

sub START {
	my ( $self ) = @_;
	$self->logger->debug('START');
	my $filter = POE::Filter::Stackable->new();
	$filter->push( POE::Filter::Line->new() );
	$filter->push( POE::Filter::IRCD->new(debug => 1) );
	POE::Component::Server::TCP->new(
		Alias                 => $self->alias,
		Address               => $self->ip,
		Port                  => $self->port,
		ClientFilter          => $filter,
		ClientInput           => sub { my @args = @_[ HEAP, ARG0..$#_ ]; $self->yield('ircd_line',@args) },
		ClientConnected       => sub { my @args = @_[ HEAP, ARG0..$#_ ]; $self->yield('ircd_connect',@args) },
		ClientDisconnected    => sub { my @args = @_[ HEAP, ARG0..$#_ ]; $self->yield('ircd_disconnect',@args) },
		Started               => sub { my @args = @_[ HEAP, ARG0..$#_ ]; $self->yield('ircd_setup',@args) },
	);
}

event ircd_setup => sub {
	my ($self, $tcpheap, @args) = @_[ OBJECT, ARG0..$#_ ];
	$self->logger->info('Startup of the ircd...');
};

event ircd_connect => sub {
	my ($self, $tcpheap, @args) = @_[ OBJECT, ARG0..$#_ ];
	$self->logger->debug('event ircd_connect from '.$tcpheap->{remote_ip});
	$self->add_tcpheap($tcpheap);
	$self->notice($tcpheap, $self->server_version);
};

event ircd_disconnect => sub {
	my ($self, $tcpheap, @args) = @_[ OBJECT, ARG0..$#_ ];
	$self->logger->debug('event ircd_disconnect by '.$tcpheap->{remote_ip});
};

sub new_event {
	my ( $self, $event, $extra_text ) = @_;
	$extra_text = '' unless $extra_text;
	my $return = 0;
	if (ref $event eq 'App::Pocobo::Event::Message') {
		my $net = defined $self->net_map->{$event->net} ? $self->net_map->{$event->net} : $event->net;
		for (@{$self->tcpheaps}) {
			my @receiver;
			for my $to (@{$event->message->to}) {
				if ($to->yourself) {
					push @receiver, $_->{nick};
				} else {
					push @receiver, $to->name;
				}
			}
			if (defined $_->{client}) {
				$self->from_command($_,$net."'".$event->message->from->name,'PRIVMSG',join(',',@receiver),$extra_text.$event->message->text);
				$return = 1;
			}
		}
	}
	return $return;
}

sub new_event_cached {
	my ( $self, $event ) = @_;
	$self->new_event( $event, '['.$event->created->strftime($self->strftime).'] ' );
}

sub from_command {
	my ( $self, $tcpheap, $from, $command, @params ) = @_;
	$self->logger->debug('sending from '.$from.' command '.$command.' to '.$tcpheap->{remote_ip});
	$tcpheap->{client}->put({
		command => $command,
		prefix => $from,
		params => \@params,
	});
}

sub from_command_nick {
	my ( $self, $tcpheap, $from, $command, @params ) = @_;
	$self->logger->debug('sending from '.$from.' command_nick '.$command.' to '.$tcpheap->{remote_ip});
	$self->from_command($tcpheap, $from, $command, defined $tcpheap->{nick} ? $tcpheap->{nick} : '*', @params);
}

sub command {
	my ( $self, $tcpheap, $command, @params ) = @_;
	$self->logger->debug('sending command '.$command.' to '.$tcpheap->{remote_ip});
	$tcpheap->{client}->put({
		command => $command,
		prefix => $self->server_host,
		params => \@params,
	});
}

sub user_command {
	my ( $self, $tcpheap, $command, @params ) = @_;
	$self->logger->debug('sending user_command '.$command.' to '.$tcpheap->{remote_ip});
	$tcpheap->{client}->put({
		command => $command,
		prefix => $tcpheap->{nick}.'!'.( defined $tcpheap->{username} ? $tcpheap->{username} : 'nobody' ).'@'.$tcpheap->{remote_ip},
		params => \@params,
	});
}

sub command_nick {
	my ( $self, $tcpheap, $command, @params ) = @_;
	$self->logger->debug('sending command_nick '.$command.' to '.$tcpheap->{remote_ip});
	$self->command($tcpheap, $command, defined $tcpheap->{nick} ? $tcpheap->{nick} : '*', @params);
}

sub notice {
	my ( $self, $tcpheap, $text ) = @_;
	$self->logger->debug('sending notice to '.$tcpheap->{remote_ip});
	$self->command_nick($tcpheap, 'NOTICE', $text);
}

sub connection_loggedin {
	my ( $self, $tcpheap ) = @_;
	return 1 if $tcpheap->{loggedin};
	if (defined $tcpheap->{password} and $tcpheap->{password} eq $self->password) {
		$self->logger->info('login successful from '.$tcpheap->{remote_ip});
		$tcpheap->{loggedin} = 1;
		$self->command_nick($tcpheap, '001', 'Welcome to your '.$self->name.', my master!');
		$self->command_nick($tcpheap, '002', 'Your host is '.$self->server_host.'['.$self->ip.'/'.$self->port.'], running version '.$self->server_version);
		$self->command_nick($tcpheap, '003', 'This server was created ....');

		# $self->user_command($tcpheap, 'JOIN', '#bots');

		# $self->command_nick($tcpheap, '332', '#bots', 'nperez is an eve addict');
		# $self->command_nick($tcpheap, '333', '#bots', 'apeiron!apeiron@shadow.cat', '1277230709');
		# $self->command_nick($tcpheap, '353', '=', '#bots', $tcpheap->{nick}.' semifor %@%%%@preflex @slavorg +workbench @dngor stephan48 +buubot knewt2 @Schuyler @imMute Getty LotR +GumbyBRAIN @Hinrik @hex @knewt nperez +phenny @GumbyNET5 @Bender @GumbyNET4 @GumbyNET3 @perigrin @BinGOs');
		# $self->command_nick($tcpheap, '366', '#bots', 'End of /NAMES list.');
		# $self->command_nick($tcpheap, '353', '=', '#bots', $tcpheap->{nick}.' semifor @slavorg +workbench @dngor stephan48 +buubot knewt2 @Schuyler @imMute Getty LotR +GumbyBRAIN @Hinrik @hex @knewt nperez +phenny @GumbyNET5 @Bender @GumbyNET4 @GumbyNET3 @perigrin @BinGOs');

# :magnet.shadowcat.co.uk 332 Getty2 #bots :nperez is an eve addict
# :magnet.shadowcat.co.uk 333 Getty2 #bots apeiron!apeiron@shadow.cat 1277230709
# :magnet.shadowcat.co.uk 353 Getty2 = #bots :Getty2 semifor preflex @slavorg +workbench @dngor stephan48 +buubot knewt2 @Schuyler @imMute Getty LotR +GumbyBRAIN @Hinrik @hex @knewt nperez +phenny @GumbyNET5 @Bender @GumbyNET4 @GumbyNET3 @perigrin @BinGOs
# :magnet.shadowcat.co.uk 366 Getty2 #bots :End of /NAMES list.

		$self->yield('get_events');

		return 1;
	}
	return 0;
}

event get_events => sub {
	my ( $self ) = @_;
	$self->logger->debug('event get_events');
	$self->pocobo->give_events($self);
};

event ircd_line => sub {
	my ($self, $tcpheap, $cmd) = @_[ OBJECT, ARG0, ARG1 ];
	$self->logger->debug('event ircd_line');
	if ($cmd->{command} eq 'PASS') {
		my $pass = $cmd->{params}->[0];
		$tcpheap->{password} = $pass;
	}
	if ($cmd->{command} eq 'NICK') {
		my $nick = $cmd->{params}->[0];
		$tcpheap->{nick} = $nick;
	}
	return unless defined $tcpheap->{nick};
	if ($cmd->{command} eq 'USER') {
		$tcpheap->{username} = $cmd->{params}->[0];
		$tcpheap->{realname} = $cmd->{params}->[3];
		return;
	}
	if (!$self->connection_loggedin( $tcpheap )) {
		$self->notice($tcpheap, 'Your IRC Client did not support a password. Please type /QUOTE PASS yourpassword to connect.');
		return;
	}
	$self->logger->debug('yielding for command '.$cmd->{command}.' from '.$tcpheap->{remote_ip});
	$self->yield('ircd_cmd_'.lc($cmd->{command}), $tcpheap, $cmd->{params});
};

event ircd_cmd_userhost => sub {
	my ($self, $tcpheap, $params) = @_[ OBJECT, ARG0, ARG1 ];
	$self->logger->debug('event ircd_cmd_userhost');
};

event ircd_cmd_ping => sub {
	my ( $self, $tcpheap, $params ) = @_[ OBJECT, ARG0, ARG1 ];
	$self->logger->debug('event ircd_cmd_ping');
	$self->command($tcpheap, 'PONG');
};

1;