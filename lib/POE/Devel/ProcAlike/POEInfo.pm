# Declare our package
package POE::Devel::ProcAlike::POEInfo;
use strict; use warnings;

# Initialize our version
use vars qw( $VERSION );
$VERSION = '0.01';

# Set our superclass
use base 'Filesys::Virtual::Async::inMemory';

# portable tools
use File::Spec;

# import the useful $poe_kernel
use POE;
use POE::API::Peek;
my $api = POE::API::Peek->new();
my $have_stats = 0;

sub new {
	# do we have stats available?
	eval { $have_stats = $poe_kernel->stat_getdata() };
	if ( ! $@ and defined $have_stats ) {
		$have_stats = 1;
	}

	# make sure we set a readonly filesystem!
	return __PACKAGE__->SUPER::new(
		'readonly'	=> 1,
	);
}

#/kernel
#	# place for kernel stuff
#
#	id		# $poe_kernel->ID
#	is_running	# $api->is_kernel_running
#	which_loop	# $poe_kernel->poe_kernel_loop
#	safe_signals	# $api->get_safe_signals
#
#	active_session	# $poe_kernel->get_active_session->ID
#	active_event	# $poe_kernel->get_active_event
#
#	memory_size	# $api->kernel_memory_size
#	session_count	# $api->session_count
#	extref_count	# $api->extref_count
#	handle_count	# $api->handle_count
#	event_count	# $poe_kernel->get_event_count
#	next_event	# $poe_kernel->get_next_event_time
#
#	/statistics
#		# stats gathered via TRACE_STATISTICS if available
#
#		interval
#
#		blocked
#		blocked_seconds
#		idle_seconds
#		total_duration
#		user_events
#		user_seconds
#
#		avg_blocked
#		avg_blocked_seconds
#		avg_idle_seconds
#		avg_total_duration
#		avg_user_events
#		avg_user_seconds
#
#		derived_idle
#		derived_user
#		derived_blocked
#		derived_userload
#
#	/eventqueue
#		# a place for the event queue data ( basically a dump of POE::Queue::Array ) - from $api->event_queue_dump()
#
#		/N
#			# N is the ID of event in the queue
#
#			id
#			index
#			priority
#			event
#			source
#			destination
#			type
#
#	/sessions
#		# place for all session info ( like /proc/pid ) - from $api->session_list
#
#		/id
#			# the id is the session ID
#
#			id				# $session->ID
#			type			# ref( $session )
#			memory_size		# $api->session_memory_size( $session )
#			extref_count	# $api->get_session_extref_count( $session )
#			handle_count	# $api->session_handle_count( $session )
#
#			events_to		# $api->event_count_to( $session )
#			events_from		# $api->event_count_from( $session )
#
#			watched_signals	# $api->signals_watched_by_session( $session )
#			events			# $api->session_event_list( $session )
#			aliases			# $api->session_alias_list( $session )
#
#			heap			# Data::Dumper( $session->get_heap() )
my %fs = (
	'id'			=> $poe_kernel->ID,
	'is_running'		=> [ $api, 'is_kernel_running' ],
	'which_loop'		=> $poe_kernel->poe_kernel_loop,
	'safe_signals'		=> join( "\n", $api->get_safe_signals() ),
	'active_session'	=> [ $poe_kernel, 'get_active_session', 'ID' ],
	'active_event'		=> [ $poe_kernel, 'get_active_event' ],
	'memory_size'		=> [ $api, 'kernel_memory_size' ],
	'session_count'		=> [ $api, 'session_count' ],
	'extref_count'		=> [ $api, 'extref_count' ],
	'handle_count'		=> [ $api, 'handle_count' ],
	'event_count'		=> [ $poe_kernel, 'get_event_count' ],
	'next_event'		=> [ $poe_kernel, 'get_next_event_time' ],

	'statistics'		=> \&manage_statistics,

	'eventqueue'		=> \&manage_queue,

	'sessions'		=> \&manage_sessions,
);

# helper sub to keep track of stat variables
sub _get_statistics {
	return [ qw( blocked blocked_seconds idle_seconds interval total_duration user_events user_seconds
		avg_blocked avg_blocked_seconds avg_idle_seconds avg_total_duration avg_user_events avg_user_seconds
		derived_idle derived_user derived_blocked derived_userload
	) ];
}
sub _get_statistics_metric {
	my $metric = shift;
	my %average = $poe_kernel->stat_getdata();

	# derived require calculations
	if ( $metric =~ /^derived/ ) {
		# Division by zero sucks.
		$average{'interval'}	||= 1;
		$average{'user_events'}	||= 1;

		if ( $metric eq 'derived_idle' ) {
			return sprintf( "%9.1f%%", 100 * $average{'avg_idle_seconds'} / $average{'interval'} );
		} elsif ( $metric eq 'derived_user' ) {
			return sprintf( "%9.1f%%", 100 * $average{'avg_user_seconds'} / $average{'interval'} );
		} elsif ( $metric eq 'derived_blocked' ) {
			return sprintf( "%9.1f%%", 100 * $average{'avg_blocked'} / $average{'user_events'} );
		} elsif ( $metric eq 'derived_userload' ) {
			return sprintf( "%9.1f%%", 100 * $average{'avg_user_events'} / $average{'interval'} );
		}
	} else {
		# simple hash access
		return $average{ $metric };
	}
}

sub manage_statistics {
	my( $type, @path ) = @_;

	# what's the operation?
	if ( $type eq 'readdir' ) {
		# do we have stats?
		if ( $have_stats ) {
			return _get_statistics();
		} else {
			return [];
		}
	} elsif ( $type eq 'stat' ) {
		# set some default data
		my ($atime, $ctime, $mtime, $size, $modes);
		$atime = $ctime = $mtime = time();
		my ($dev, $ino, $rdev, $blocks, $gid, $uid, $nlink, $blksize) = ( 0, 0, 0, 1, (split( /\s+/, $) ))[0], $>, 1, 1024 );

		# trying to stat the dir or stuff inside it?
		if ( defined $path[0] ) {
			# do we have stats?
			if ( ! $have_stats ) {
				return;
			}

			# is it a valid stat metric?
			if ( ! grep { $_ eq $path[0] } @{ _get_statistics() } or defined $path[1] ) {
				return;
			}

			# a file, munge the data
			$size = length( _get_statistics_metric( $path[0] ) );
			$modes = oct( '100644' );
		} else {
			# a directory, munge the data
			$size = 0;
			$modes = oct( '040755' );
			$nlink = 2;
		}

		# finally, return the darn data!
		return( [ $dev, $ino, $modes, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks ] );
	} elsif ( $type eq 'open' ) {
		# return a scalar ref
		my $data = _get_statistics_metric( $path[0] );
		return \$data;
	}
}

# helper sub to simplify queue item processing
sub _get_queues {
	return [ qw( id index priority event source destination type ) ];
}
sub _get_queue_metric {
	my $queue_id = shift;
}

sub manage_queue {
	my( $type, @path ) = @_;

	# what's the operation?
	if ( $type eq 'readdir' ) {
		# trying to read the root or the queue event itself?
		if ( defined $path[0] ) {
			return _get_queues();
		} else {
			# get the queue events
			my @queue = map { $_->{'ID'} } @{ $api->event_queue_dump() };
			return \@queue;
		}
	}
}

# we cheat here and not implement a lot of stuff because we know the FUSE api never calls the "extra" APIs
# that ::Async provides. Furthermore, this is a read-only filesystem so we can skip even more APIs :)

# _rmtree

# _scandir

# _move

# _copy

# _load

sub _readdir {
	my( $self, $path ) = @_;

	if ( $path eq File::Spec->rootdir() ) {
		return [ keys %fs ];
	} else {
		# sanitize the path
		my @dirs = File::Spec->splitdir( $path );
		shift( @dirs ); # get rid of the root entry which is always '' for me
		return $fs{ $dirs[0] }->( 'readdir', @dirs[ 1 .. $#dirs ] );
	}
}

# _rmdir

# _mkdir

# _rename

# _mknod

# _unlink

# _chmod

# _truncate

# _chown

# _utime

sub _stat {
	my( $self, $path ) = @_;

	# stating the root?
	if ( $path eq File::Spec->rootdir() ) {
		my ($atime, $ctime, $mtime, $size, $modes);
		$atime = $ctime = $mtime = time();
		my ($dev, $ino, $rdev, $blocks, $gid, $uid, $nlink, $blksize) = ( 0, 0, 0, 1, (split( /\s+/, $) ))[0], $>, 1, 1024 );
		$size = 0;
		$modes = oct( '040755' );

		# count subdirs
		$nlink = 2 + grep { ref $fs{ $_ } } keys %fs;

		return( [ $dev, $ino, $modes, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks ] );
	}

	# sanitize the path
	my @dirs = File::Spec->splitdir( $path );
	shift( @dirs ); # get rid of the root entry which is always '' for me
	if ( exists $fs{ $dirs[0] } ) {
		# directory or file?
		if ( ref $fs{ $dirs[0] } ) {
			# trying to stat the dir or the subpath?
			return $fs{ $dirs[0] }->( 'stat', @dirs[ 1 .. $#dirs ] );
		} else {
			# arg, stat is a finicky beast!
			my $size = length( $fs{ $dirs[0] } );
			my $modes = oct( '100644' );

			my ($dev, $ino, $rdev, $blocks, $gid, $uid, $nlink, $blksize) = ( 0, 0, 0, 1, (split( /\s+/, $) ))[0], $>, 1, 1024 );
			my ($atime, $ctime, $mtime);
			$atime = $ctime = $mtime = time();

			# finally, return the darn data!
			return( [ $dev, $ino, $modes, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks ] );
		}
	} else {
		return;
	}
}

# _write

sub _open {
	my( $self, $path ) = @_;

	# sanitize the path
	my @dirs = File::Spec->splitdir( $path );
	shift( @dirs ); # get rid of the root entry which is always '' for me
	if ( exists $fs{ $dirs[0] } ) {
		# directory or file?
		if ( ref $fs{ $dirs[0] } ) {
			return $fs{ $dirs[0] }->( 'open', @dirs[ 1 .. $#dirs ] );
		} else {
			# return a scalar ref
			return \$fs{ $dirs[0] };
		}
	} else {
		return;
	}
}

1;
__END__

=head1 NAME

POE::Devel::ProcAlike::POEInfo - Manages the POE data in ProcAlike

=head1 SYNOPSIS

  Please do not use this module directly.

=head1 ABSTRACT

Please do not use this module directly.

=head1 DESCRIPTION

This module is responsible for exporting the POE data in ProcAlike.

=head1 EXPORT

None.

=head1 SEE ALSO

L<POE::Devel::ProcAlike>

=head1 AUTHOR

Apocalypse E<lt>apocal@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2009 by Apocalypse

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut