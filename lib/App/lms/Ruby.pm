package App::lms::Ruby;

use v5.14;
use warnings;
use Command::Run;

my $RUBY;
my $DEBUG;

sub man_cmd {
    my($app, $name, $path) = @_;
    return ('ri', $name);
}

sub get_path {
    my($app, $name) = @_;
    $DEBUG = $app->debug;
    my $ruby = _find_ruby() or do {
        warn "  Ruby not found\n" if $DEBUG;
        return;
    };
    warn "  Using: $ruby\n" if $DEBUG;

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
        warn "  Found: @paths\n" if $DEBUG;
        return @paths;
    }
    return;
}

sub _find_ruby {
    return $RUBY if defined $RUBY;
    Command::Run->new->command('which', 'ruby')->update->data
        and return $RUBY = 'ruby';
    return $RUBY = '';
}

1;
