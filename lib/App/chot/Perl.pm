package App::chot::Perl;
use v5.14;
use warnings;

use parent 'App::chot::Finder';

use Digest::MD5;

#
# Use perldoc -F to show documentation for the first found Perl file.
# Retrieves this handler's own paths via context->paths_for('Perl'),
# avoiding the former bug where $found[0] could be another handler's path.
#
sub man_cmd {
    my $self = shift;
    my @paths = $self->found->paths_for('Perl');
    return unless @paths;
    return ('perldoc', '-F', $paths[0]);
}

#
# Search @INC and Homebrew lib paths for .pm/.pl files.
# Deduplicates by content hash to avoid showing identical files
# installed in multiple locations.
#
sub get_path {
    my $self = shift;
    my($app, $name) = ($self->app, $self->name);

    my @libs = grep { $app->valid($_) } ( @INC, homebrew_perl_libs() );
    warn "  Searching in " . scalar(@libs) . " directories\n" if $self->debug;

    my @found =
    grep { -f $_ and -r $_ }
    map  { s[::][/]gr }
    map  { ( "$_/$name", "$_/$name.pm", "$_/$name.pl" ) }
    @libs;

    warn "  Found: @found\n" if $self->debug && @found;

    # Deduplicate files with identical content
    my %seen;
    @found = grep {
        open my $fh, '<', $_ or return 1;
        my $hash = Digest::MD5->new->addfile($fh)->hexdigest;
        !$seen{$hash}++;
    } @found;

    return @found;
}

#
# Pure function: find Homebrew-installed Perl lib directories.
#
sub homebrew_perl_libs {
    my $prefix = $ENV{HOMEBREW_PREFIX}
              // (-d '/opt/homebrew' ? '/opt/homebrew' : undef)
              // (-d '/usr/local/Homebrew' ? '/usr/local' : undef)
              // (-d '/home/linuxbrew/.linuxbrew' ? '/home/linuxbrew/.linuxbrew' : undef)
              // return;

    # Search in opt/*/libexec/lib/perl5
    glob("$prefix/opt/*/libexec/lib/perl5");
}

1;
