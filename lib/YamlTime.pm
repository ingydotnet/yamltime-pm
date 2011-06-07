##
# name:      YamlTime
# abstract:  YAML based Personal Time Tracking
# author:    Ingy döt Net
# license:   perl
# copyright: 2011
# see:
# - YAML

#-----------------------------------------------------------------------------#
package YamlTime;
use 5.008003;

our $VERSION = '0.01';

use Mouse;
extends 'MouseX::App::Cmd';

#-----------------------------------------------------------------------------#
package YamlTime::Command;
use Mouse;
extends qw(MouseX::App::Cmd::Command);

use YAML::XS 0.35 ();
use IO::All 0.41;
use DateTime 0.70 ();
use DateTime::Format::Natural 0.94 ();
use File::ShareDir 1.03 ();
use Cwd qw[cwd abs_path];
use XXX;

has config => (
    is => 'ro',
    builder => 'config__',
    lazy => 1,
);
has base => (
    is => 'ro',
    default => sub { abs_path($ENV{YAMLTIME_BASE} || '.') },
);

sub BUILD {
    my ($self) = @_;
    my $base = $self->base;
    chdir $base or $self->error("Can't chdir to '%s'", $base);
}

#-----------------------------------------------------------------------------#
# A role for time range options
package YamlTime::TimeOpts;
use Mouse::Role;

my $time = time;

has from => (is => 'ro', isa => 'Str', default => $time - 24*3600);
has to => (is => 'ro', isa => 'Str', default => $time);

#-----------------------------------------------------------------------------#
# status - Check the YamlTime system status
package YamlTime::Command::status;
use Mouse;
extends qw(YamlTime::Command);

use constant abstract => '';

# sub execute {
#     my ($self) = @_;
# }

#-----------------------------------------------------------------------------#
# = YamlTime (yt) Commands

# init - Initialize a new YamlTime repo
package YamlTime::Command::init;
use Mouse;
extends qw(YamlTime::Command);

use constant abstract => 'Initialize a new YamlTime repo';
has force => (
    is => 'ro',
    isa => 'Bool',
    documentation => 'Force an init operation',
);

sub execute {
    my ($self) = @_;
    if ($self->empty_directory or $self->force) {
        my $share = $self->share;
        $self->copy_files("$share/conf", "./conf");
        mkdir($self->date('now')->year);
    }
    else {
        $self->error(
            "Won't 'init' in a non empty directory, unless you use --force"
        );
    }
}

#-----------------------------------------------------------------------------#
# new - Start a new task/timer
package YamlTime::Command::new;
use Mouse;
extends qw(YamlTime::Command);

# sub execute {
#     my ($self) = @_;
# }

#-----------------------------------------------------------------------------#
## stop - Stop the timer on the current task
package YamlTime::Command::stop;
use Mouse;
extends qw(YamlTime::Command);

# sub execute {
#     my ($self) = @_;
# }

#-----------------------------------------------------------------------------#
# go - Restart a task
package YamlTime::Command::go;
use Mouse;
extends qw(YamlTime::Command);

# sub execute {
#     my ($self) = @_;
# }

#-----------------------------------------------------------------------------#
# check - Check that the YamlTime store for problems
package YamlTime::Command::check;
use Mouse;
extends qw(YamlTime::Command);
with 'YamlTime::TimeOpts';

use constant abstract => '';

# sub execute {
#     my ($self) = @_;
# }

#-----------------------------------------------------------------------------#
# report - Produce a billing report or invoice
package YamlTime::Command::report;
use Mouse;
extends 'YamlTime::Command';
with 'YamlTime::TimeOpts';

sub execute {
    my ($self) = @_;
    $self->xxx;
}

#-----------------------------------------------------------------------------#
# The rest of the base class
package YamlTime::Command;

use constant abstract => '';

sub config__ {
    my ($self) = @_;
    $self->error("No yt config file found in '%s'\n", $self->cwd)
        unless -e "conf";
}

sub cmd {
    my ($self) = @_;
    ((my $name = ref($self)) =~ s/.*://);
    return $name;
}

sub execute {
    my ($self) = @_;
    $self->error("'%s' not yet imlemented\n", $self->cmd);
}

sub error {
    my ($self, $msg) = splice(@_, 0, 2);
    die sprintf($msg, @_);
}

#-----------------------------------------------------------------------------#
# Guts of the machine

my $date_parser = DateTime::Format::Natural->new;

sub date {
    my ($self, $string) = @_;
    return eval {
        $date_parser->parse_datetime($string);
    } || undef;
}

sub empty_directory {
    io('.')->empty;
}

sub share {
    my $self = shift;
    my $path = $INC{'YamlTime.pm'} or die;
    if ($path =~ s!(\S.*?)[\\/]?\bb?lib\b.*!$1! and
        -e "$path/Makefile.PL" and
        -e "$path/share"
    ) {
        return abs_path "$path/share";
    }
    else {
        return File::ShareDir::dist_dir('YamlTime');
    }
}

sub copy_files {
    my ($self, $source, $target) = @_;
    for my $file (io($source)->All_Files) {
        my $short = $file->name;
        $short =~ s!^\Q$source\E/?!! or die $short;
        io("$target/$short")->assert->print($file->all);
    }
}

1;

=head1 SYNOPSIS

    > yt help

=head1 DESCRIPTION

YamlTime is an application that allows you do your personal project time
tracking from the command line. It saves your data in plain text YAML files.
You can use a version control system (like git) to back up the data.

YamlTime comes with a command line app called C<yt> that does everything.

=head1 COMMANDLINE USAGE

The following commands are supported.

    yt                  - Show current yt status
    yt help             - Get Help
    yt init             - Create a new YamlTime store
    yt new              - Start a new task
    yt stop             - Stop the current task
    yt go               - Restart the current task
    yt edit <task>      - Edit a tasks yaml file
    yt check <range>    - Check the data in the range
    yt status <option>  - Show the current yt status
    yt report <range> <style>
                        - Create a report for a time period
                          using a certain reporting style

=head2 Options

yt commands have the following options:

=over

=item --from=<date_string>

Commands that need a time range, use this to set the start time. The default
is the previous midnight. A human friendly string can be used, like: '3 days
ago'.

=item --to=<date_string>

Commands that need a time range, use this to set the end time. The default
is now.

=item --style=<report-style>

This names a YamlTime reporting style. The default is CSV, which can be used
as a spreadsheet.

=back
