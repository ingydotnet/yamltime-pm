##
# name:      YamlTime
# abstract:  YAML based Personal Time Tracking
# author:    Ingy döt Net <ingy@cpan.org>
# license:   perl
# copyright: 2011
# see:
# - YAML

#-----------------------------------------------------------------------------#
package YamlTime;
use 5.008003;

our $VERSION = '0.02';
our $Conf;

use Mouse;
extends 'MouseX::App::Cmd';

use YamlTime::Conf;
use YamlTime::Task;
use YAML::XS 0.35 ();
use IO::All 0.41 ();
use DateTime 0.70 ();
use DateTime::Format::Natural 0.94 ();
use File::ShareDir 1.03 ();
use Template::Toolkit::Simple 0.13 ();
use Template::Plugin::YAMLVal 0.10 ();
use Term::Prompt 1.04 ();

use constant usage => 'YamlTime::Command';

#-----------------------------------------------------------------------------#
package YamlTime::Command;
use Mouse;
extends qw[MouseX::App::Cmd::Command];

use IO::All;
use Cwd qw[cwd abs_path];
use Term::Prompt qw[prompt];
# use XXX;

use constant text => <<'...';
This is the YamlTime personal time tracker.

Usage:

    yt
    yt <options> command
    yt <options> new <task description>
...

has conf => (
    is => 'ro',
    lazy => 1,
    builder => sub {
        my ($self) = @_;
        return $YamlTime::Conf =
            YamlTime::Conf->new(base => $self->base);
    },
);
has base => (
    is => 'ro',
    default => sub { abs_path($ENV{YAMLTIME_BASE} || '.') },
);

sub BUILD {
    my ($self) = @_;
}

sub validate_args {
    my ($self) = @_;
    my $base = $self->base;
    chdir $base or $self->error("Can't chdir to '%s'", $base);
    $self->conf unless ref($self) =~ /::init$/;
}

# A generic command abstract
use constant abstract => 'abtract not yet defined :(';

# A generic stub for command execution
sub execute {
    my ($self) = @_;
    ((my $cmd = ref($self)) =~ s/.*://);
    $self->error("'%s' not yet imlemented\n", $self->cmd);
}

#-----------------------------------------------------------------------------#
# A role for time range options
#-----------------------------------------------------------------------------#
package YamlTime::TimeOpts;
use Mouse::Role;

my $time = time;

has from => (is => 'ro', isa => 'Str', default => $time - 24*3600);
has to => (is => 'ro', isa => 'Str', default => $time);

#-----------------------------------------------------------------------------#
# YamlTime (yt) Commands
#-----------------------------------------------------------------------------#
package YamlTime::Command::init;
use Mouse;
extends qw[YamlTime::Command];

use constant abstract => 'Initialize a new YamlTime store directory';

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
            "Won't 'init' in a non empty directory, unless you use --force\n"
        );
    }
}

#-----------------------------------------------------------------------------#
package YamlTime::Command::new;
use Mouse;
extends qw[YamlTime::Command];

use constant abstract => 'Create a new task and start the timer';

sub execute {
    my ($self, $opt, $args) = @_;
    $self->error__already_in_progress
        if $self->current_task and
            $self->current_task->in_progress;

    my $task = YamlTime::Task->new(id => undef);
    $self->populate($task, $args);
    $task->start;

    $self->log("Started task " . $task->id);
}

#-----------------------------------------------------------------------------#
package YamlTime::Command::stop;
use Mouse;
extends qw[YamlTime::Command];

use constant abstract => 'Stop the timer on a running task';

sub execute {
    my ($self) = @_;
    my $task = $self->current_task or
        $self->error__no_current_task;
    $task->error__not_in_progress
        unless $task->in_progress;

    $task->stop;
}

#-----------------------------------------------------------------------------#
package YamlTime::Command::go;
use Mouse;
extends qw[YamlTime::Command];

use constant abstract => 'Restart the timer on a task';

sub execute {
    my ($self, $opt, $args) = @_;
    my $id = $args->[0];
    my $task = $id
        ? YamlTask->new(id => $id)
        : $self->current_task
            or $self->error__no_current_task;
    $self->error__already_in_progress
        if $task->in_progress;
    $task->start;
}

#-----------------------------------------------------------------------------#
package YamlTime::Command::status;
use Mouse;
extends qw[YamlTime::Command];
with 'YamlTime::TimeOpts';

use constant abstract => 'Show the status of a range of tasks';

sub execute {
    my ($self, $opt, $args) = @_;
    for my $task ($self->task_range) {
        printf "%1s %12s %5s %s\n",
            ($task->in_progress ? '+' : '-'),
            $task->id,
            $task->elapsed,
            $task->task;
    }
}

#-----------------------------------------------------------------------------#
package YamlTime::Command::check;
use Mouse;
extends qw[YamlTime::Command];
with 'YamlTime::TimeOpts';

use constant abstract => 'Check the validity of a range of tasks';

#-----------------------------------------------------------------------------#
package YamlTime::Command::report;
use Mouse;
extends 'YamlTime::Command';
with 'YamlTime::TimeOpts';

use constant abstract => 'Produce a billing report from a range of tasks';

#-----------------------------------------------------------------------------#
package YamlTime::Command::edit;
use Mouse;
extends qw[YamlTime::Command];
with 'YamlTime::TimeOpts';

use constant abstract => 'Edit a task\'s YAML in $EDITOR';

#-----------------------------------------------------------------------------#
package YamlTime::Command::dump;
use Mouse;
extends qw[YamlTime::Command];
with 'YamlTime::TimeOpts';

use constant abstract => 'Print a task file to STDOUT';

#-----------------------------------------------------------------------------#
package YamlTime::Command::store;
use Mouse;
extends qw[YamlTime::Command];
with 'YamlTime::TimeOpts';

use constant abstract => 'Write to a task file from STDIN';

#-----------------------------------------------------------------------------#
# Guts of the machine
package YamlTime::Command;

sub current_task {
    my ($self) = @_;
    return unless -e '_';
    return YamlTime::Task->new(id => readlink('_'));
}

sub task_range {
    my ($self) = @_;
    my $now = $self->conf->now;
    my $dir = sprintf "%4d/%02d/%02d",
        $now->year,
        $now->month,
        $now->day;
    my @files = -d $dir ? io->dir($dir)->All_Files : ();
    return map {
        YamlTime::Task->new(id => "$_");
    } sort map $_->name, @files;
}

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
    my $class = shift;
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

my $prompts = {
    task => 'Task Description: ',
    cust => 'Customer Id: ',
    tags => 'A Tag Word: ',
    proj => 'Project Id: ',
};

sub populate {
    my ($self, $task, $args) = @_;
    my $old = $self->current_task || {};
    $task->{task} = join ' ', @$args if @$args;
    for my $key (qw[task cust proj tags]) {
        my $val = $task->$key;
        my $list = ref($val);
        next if $list ? @$val : length $val;
        my $default = not($list) && $old->{$key} || '';
        my $prompt = $prompts->{$key};
        while (1) {
            my $nval = prompt('S', $prompt, '', $default, sub {
                my $v = shift;
                if (not length $v) {
                    return ($key ne 'task');
                }
                if ($key =~ /^(cust|proj|tags)$/) {
                    return exists $self->conf->{$key}{$v};
                }
                return ($v =~ /\S/);
            });
            last unless $nval;
            $nval =~ s/^\s*(.*?)\s*$/$1/;
            if ($list) {
                push @$val, $nval;
            }
            else {
                $task->$key($nval);
                last;
            }
        }
    }
}

sub log {
    my $self = shift;
    print "@_\n";
}


#-----------------------------------------------------------------------------#
# Errors happen
sub error {
    my ($self, $msg) = splice(@_, 0, 2);
    die sprintf($msg, @_);
}

sub error__already_in_progress {
    my ($self) = @_;
    $self->error(<<'...');
Command invalid.
A task is already in progress.
Stop the current one first.
...
}

sub error__not_in_progress {
    my ($self) = @_;
    $self->error(<<'...');
Command invalid.
There is no task is currently in progress.
...
}

sub error__no_current_task {
    my ($self) = @_;
    $self->error(<<'...');
Command invalid.
There is no current task.
You may need to specify one.
...
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

    yt                  - Show current yt status of today's tasks
    yt help             - Get Help
    yt init             - Create a new YamlTime store
    yt new              - Start a new task
    yt stop             - Stop the current task
    yt go               - Restart the current task
    yt edit <task>      - Edit a task's yaml file in $EDITOR
    yt dump <task>      - Read a task file and print to STDOUT
    yt save <task>      - Read STDIN and print to a task file
    yt check <range>    - Check the data in the range
    yt status <range>   - Show the current yt status
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

=item --tag=<tag_list>

A comma separated list of tags. Matches tasks the match all the tags. You can specify more than once to combine ('or' logig) groups.

=item --style=<report-style>

This names a YamlTime reporting style. The default is CSV, which can be used
as a spreadsheet.

=back
