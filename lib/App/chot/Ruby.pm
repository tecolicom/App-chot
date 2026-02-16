package App::chot::Ruby;

use v5.14;
use warnings;

use parent 'App::chot::Finder';

use Command::Run;

#
# Use ri (Ruby Interactive reference) for documentation.
#
sub man_cmd {
    my $self = shift;
    return ('ri', $self->name);
}

#
# Find Ruby library source by requiring it and inspecting $LOADED_FEATURES.
#
sub get_path {
    my $self = shift;
    my $name = $self->name;
    my $ruby = $self->_find_ruby or do {
        warn "  Ruby not found\n" if $self->debug;
        return;
    };
    warn "  Using: $ruby\n" if $self->debug;

    # Validate module name
    return if $name =~ /[^\w.\-\/]/;

    my $code = <<"END";
begin
  require '$name'
  \$LOADED_FEATURES.select { |f| f.include?('$name') }.each { |f| puts f }
rescue LoadError
end
END

    my $data = Command::Run->new->command($ruby, '-e', $code)->update->data // return;
    my @paths = grep { -f } split /\n/, $data;
    if (@paths) {
        warn "  Found: @paths\n" if $self->debug;
        return @paths;
    }
    return;
}

#
# Find available Ruby interpreter. Result is cached per instance.
#
sub _find_ruby {
    my $self = shift;
    return $self->{_ruby} if defined $self->{_ruby};
    Command::Run->new->command('which', 'ruby')->update->data
        and return $self->{_ruby} = 'ruby';
    return $self->{_ruby} = '';
}

1;
