# Build.PL
use strict; use warnings;
use Module::Build;

my $build = Module::Build->new(
	# look up Module::Build::API for the info!
	'dynamic_config'	=> 0,
	'module_name'		=> 'POE::Devel::ProcAlike',
	'license'		=> 'perl',

	'dist_abstract'		=> "Exposing POE guts via FUSE",
	'dist_author'		=> 'Apocalypse <APOCAL@cpan.org>',

	'create_packlist'	=> 1,
	'create_makefile_pl'	=> 'traditional',
	'create_readme'		=> 1,

	'test_files'		=> 't/*.t',

	'add_to_cleanup'	=> [ 'META.yml', 'Makefile.PL', 'README', 'Makefile' ],	# automatically generated

	'requires'		=> {
		# POE Stuff
		'POE'				=> '1.003',	# require latest for sanity
		'POE::Session::AttributeBased'	=> 0,
		'POE::API::Peek'		=> 0,

		# our FUSE stuff
		'Fuse'				=> '0.09',
		'POE::Component::Fuse'		=> '0.02',
		'POE::Component::AIO'		=> 0,

		# the FsV objects
		'Filesys::Virtual::Async::inMemory'	=> 0,
		'Filesys::Virtual::Async::Dispatcher'	=> 0,

		# our minimum perl version
		'perl'				=> '5.006',
	},
);

# all done!
$build->create_build_script;
