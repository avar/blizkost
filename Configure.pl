# $Id$

=head1 NAME

Configure.pl - a configure script for a high level language running on Parrot

=head1 SYNOPSIS

  perl Configure.pl --help

  perl Configure.pl

  perl Configure.pl --parrot-config=<path_to_parrot>

  perl Configure.pl --gen-parrot [ -- --options-for-configure-parrot ]

=cut

use strict;
use warnings;
use 5.008;
use Config;

use Getopt::Long qw(:config auto_help);

our ( $opt_parrot_config, $opt_gen_parrot);
GetOptions( 'parrot-config=s', 'gen-parrot' );

#  Update/generate parrot build if needed
if ($opt_gen_parrot) {
    system($^X, 'build/gen_parrot.pl', @ARGV);
}

#  Get a list of parrot-configs to invoke.
my @parrot_config_exe = $opt_parrot_config
                      ? ( $opt_parrot_config )
                      : (
                          'parrot/parrot_config',
                          '../../parrot_config',
                          'parrot_config',
                        );

#  Get configuration information from parrot_config
my %config = read_parrot_config(@parrot_config_exe);
unless (%config) {
    die "Unable to locate parrot_config.";
}

#  Create the Makefile using the information we just got
create_makefiles(%config);

#  Parrot's makefile tool doesn't give us an easy way to shove in more
#  values, so for now we'll just screw with the makefile after Parrot's
#  tool has generated it. If this bothers you, patches welcome.
open(my $fh, '< src/pmc/Makefile') || die "Could not open src/pmc/Makefile: $!";
my $mf = join('', <$fh>);
close $fh;
open($fh, '> src/pmc/Makefile') || die "Could not open src/pmc/Makefile: $!";
print $fh <<MAKEFILE;
# Perl 5 configuration bits.
P5_ARCHLIB = $Config{'archlib'}
P5_LIBPERL = $Config{'libperl'}

MAKEFILE
print $fh $mf;
close $fh;

sub read_parrot_config {
    my @parrot_config_exe = @_;
    my %config = ();
    for my $exe (@parrot_config_exe) {
        no warnings;
        if (open my $PARROT_CONFIG, '-|', "$exe --dump") {
            print "Reading configuration information from $exe\n";
            while (<$PARROT_CONFIG>) {
                $config{$1} = $2 if (/(\w+) => '(.*)'/);
            }
            close $PARROT_CONFIG;
            last if %config;
        }
    }
    %config;
}


#  Generate Makefiles from a configuration
sub create_makefiles {
    my %config = @_;
    my %makefiles = (
        'build/Makefile.in'         => 'Makefile',
        'build/src/pmc/Makefile.in' => 'src/pmc/Makefile'
    );
    my $build_tool = $config{libdir} . $config{versiondir}
                   . '/tools/dev/gen_makefile.pl';
print "$build_tool\n";
    foreach my $template (keys %makefiles) {
        my $makefile = $makefiles{$template};
        print "Creating $makefile\n";
        system($config{perl}, $build_tool, $template, $makefile);
    }
}

# Local Variables:
#   mode: cperl
#   cperl-indent-level: 4
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4:
