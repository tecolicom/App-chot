package App::chot::Finder;
use v5.14;
use warnings;

=head1 DESCRIPTION

Base class for all chot finder modules (Command, Perl, Python, Ruby, Node).

Subclasses inherit C<new()> and accessor methods, and override finder methods.

Finder contract:

=over 4

=item B<get_path()> (required)

Returns a list of file paths found for the target name.

=item B<get_info()> (optional)

Prints trace/resolution info to STDERR for C<-i> mode.

=item B<man_cmd()> (optional)

Returns a command list for displaying documentation.
Returns empty list to skip (allowing fallback to the next finder).

=back

=cut

sub new {
    my($class, %args) = @_;
    bless {
        app   => $args{app},    # App::chot option object
        name  => $args{name},   # target command/module name
        found => $args{found},  # App::chot::Found shared results
    }, $class;
}

#
# lvalue accessors: readable and writable (e.g., $self->name = 'foo')
#
sub app   : lvalue { $_[0]{app} }
sub name  : lvalue { $_[0]{name} }
sub found : lvalue { $_[0]{found} }

#
# Shortcut for $self->app->debug
#
sub debug   { $_[0]{app}->debug }

#
# Default: return empty list (subclasses override)
#
sub get_path { () }

1;
