#!/usr/bin/perl
use strict; use warnings;
use POE::Devel::ProcAlike;
use POE;

# load the FUSE stuff
POE::Devel::ProcAlike->spawn();

# create our own "fake" session
POE::Session->create(
	'inline_states'	=> {
		'_start'	=> sub {
			$_[KERNEL]->alias_set( 'foo' );
			$_[KERNEL]->yield( 'timer' );
		},
		'timer'		=> sub {
			$_[KERNEL]->delay_set( 'timer' => 60 );
		}
	},
	'heap'		=> {
		'fakedata'	=> 1,
		'oomph'		=> 'haha',
	},
);

# run the kernel!
POE::Kernel->run();
