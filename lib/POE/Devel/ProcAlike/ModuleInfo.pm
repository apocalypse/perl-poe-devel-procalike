# Declare our package
package POE::Devel::ProcAlike::ModuleInfo;
use strict; use warnings;

# Initialize our version
use vars qw( $VERSION );
$VERSION = '0.01';

# Set our superclass
use base 'Filesys::Virtual::Async::inMemory';

# portable tools
use File::Spec;

sub new {
	# make sure we set a readonly filesystem!
	return __PACKAGE__->SUPER::new(
		'readonly'	=> 1,
	);
}

#/modules
#	# place for modules to dump their info ( those who are aware of poe-devel-procalike )
#
#	/poe-component-server-simplehttp
#		# module name will be converted to above format
#		# allowed only one object per module, they can stuff any data they want in their area
my %fs = (
	# start with no modules loaded
);

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

POE::Devel::ProcAlike::ModuleInfo - Manages the PoCo module data in ProcAlike

=head1 SYNOPSIS

  Please do not use this module directly.

=head1 ABSTRACT

Please do not use this module directly.

=head1 DESCRIPTION

This module is responsible for exporting the PoCo module data in ProcAlike.

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