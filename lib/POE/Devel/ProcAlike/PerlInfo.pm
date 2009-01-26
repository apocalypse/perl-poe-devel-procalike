# Declare our package
package POE::Devel::ProcAlike::PerlInfo;
use strict; use warnings;

# Initialize our version
use vars qw( $VERSION );
$VERSION = '0.01';

# Set our superclass
use base 'Filesys::Virtual::Async::inMemory';

# portable tools
use File::Spec;

# figure out memory size
use Devel::Size qw( total_size );

sub new {
	# make sure we set a readonly filesystem!
	return __PACKAGE__->SUPER::new(
		'readonly'	=> 1,
	);
}

#/perl
#	# place for generic perl data
#
#	binary		# $^X
#	version		# $^V
#	pid		# $$
#	script		# $0
#	osname		# $^O
#	starttime	# $^T
#
#	inc		# dumps the @inc array
#
#	/env
#		# dumps the %ENV hash
#
#		PWD	# data is $ENV{PWD}
#		...
#
#	/modules
#		# lists all loaded modules
#
#		/Foo-Bar
#			# module name will be converted to above format
#
#			version		# $module->VERSION // 'UNDEF'
#			path		# module's path in %INC
my %fs = (
	'binary'	=> $^X,
	'version'	=> "$^V",
	'pid'		=> $$,
	'script'	=> $0,
	'osname'	=> $^O,
	'starttime'	=> $^T,
	'inc'		=> join( "\n", @INC ),

	'env'		=> \&manage_env,

	'modules'	=> \&manage_modules,
);

# helper to get loaded modules
sub _get_loadedmodules {
	my @list = map { my @s = File::Spec->splitdir( $_ ); my $p = join( '-', @s ); $p }
		map { $_ =~ s/\.pm$//; $_ }
		grep { $_ !~ /(?:al|ix)$/ } keys %INC; # remove /usr/lib/perl/5.10/auto/POSIX/autosplit.ix
	return \@list;
}

sub manage_modules {
	my( $type, @path ) = @_;

	# what's the operation?
	if ( $type eq 'readdir' ) {
		# trying to read the root or the module itself?
		if ( defined $path[0] ) {
			# shortcut, because we always know what's in the module dir
			return [ 'version', 'path' ];
		} else {
			# list all loaded modules
			return _get_loadedmodules();
		}
	} elsif ( $type eq 'stat' ) {
		# set some default data
		my ($atime, $ctime, $mtime, $size, $modes);
		$atime = $ctime = $mtime = time();
		my ($dev, $ino, $rdev, $blocks, $gid, $uid, $nlink, $blksize) = ( 0, 0, 0, 1, (split( /\s+/, $) ))[0], $>, 1, 1024 );

		# trying to stat the dir or stuff inside it?
		if ( defined $path[0] ) {
			# convert it back to %INC type
			my $incpath = join( '/', split( '-', $path[0] ) ) . '.pm';

			# does it exist?
			if ( ! exists $INC{ $incpath } ) {
				return;
			}

			# trying to stat the module or data inside it?
			if ( defined $path[1] ) {
				$modes = oct( '100644' );

				# stating what file?
				if ( $path[1] eq 'version' ) {
					$size = join( '::', split( '-', $path[0] ) );
					eval "$size = $size->VERSION";
					if ( defined $size ) {
						$size = length( $size );
					} else {
						$size = length( 'UNDEF' );
					}
				} elsif ( $path[1] eq 'path' ) {
					$size = length( $INC{ $incpath } );
				} else {
					return;
				}
			} else {
				# a directory, munge the data
				$size = 0;
				$modes = oct( '040755' );
				$nlink = 2;
			}
		} else {
			# a directory, munge the data
			$size = 0;
			$modes = oct( '040755' );
			$nlink = 2 + scalar @{ _get_loadedmodules() };
		}

		# finally, return the darn data!
		return( [ $dev, $ino, $modes, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks ] );
	} elsif ( $type eq 'open' ) {
		# convert it back to %INC type
		my $incpath = join( '/', split( '-', $path[0] ) ) . '.pm';

		# does it exist?
		if ( ! exists $INC{ $incpath } or ! defined $path[1] ) {
			return;
		}

		# what are we opening?
		if ( $path[1] eq 'version' ) {
			my $module = join( '::', split( '-', $path[0] ) );
			my $version = eval "$module->VERSION";
			if ( ! defined $version ) {
				$version = 'UNDEF';
			}
			return \$version;
		} elsif ( $path[1] eq 'path' ) {
			return \$INC{ $incpath };
		} else {
			return;
		}
	}
}

sub manage_env {
	my( $type, @path ) = @_;

	# what's the operation?
	if ( $type eq 'readdir' ) {
		# we don't have any subdirs so simply return the entire hash!
		return [ keys %ENV ];
	} elsif ( $type eq 'stat' ) {
		# set some default data
		my ($atime, $ctime, $mtime, $size, $modes);
		$atime = $ctime = $mtime = time();
		my ($dev, $ino, $rdev, $blocks, $gid, $uid, $nlink, $blksize) = ( 0, 0, 0, 1, (split( /\s+/, $) ))[0], $>, 1, 1024 );

		# trying to stat the dir or stuff inside it?
		if ( defined $path[0] ) {
			# does it exist?
			if ( ! exists $ENV{ $path[0] } or defined $path[1] ) {
				return;
			}

			# a file, munge the data
			$size = length( $ENV{ $path[0] } );
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
		return \$ENV{ $path[0] };
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
	if ( defined $dirs[0] and exists $fs{ $dirs[0] } ) {
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

POE::Devel::ProcAlike::PerlInfo - Manages the perl data in ProcAlike

=head1 SYNOPSIS

  Please do not use this module directly.

=head1 ABSTRACT

Please do not use this module directly.

=head1 DESCRIPTION

This module is responsible for exporting the perl data in ProcAlike.

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