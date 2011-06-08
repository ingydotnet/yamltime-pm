##
# name:      YamlTime::Task
# abstract:  YamlTime Task Object Class
# author:    Ingy döt Net
# license:   perl
# copyright: 2011
# see:
# - YamlTime

#-----------------------------------------------------------------------------#
package YamlTime::Task;
use Mouse;
use YAML::XS;
use Template::Toolkit::Simple;
use Template::Toolkit::Simple;
use IO::All;
use XXX;

sub BUILD {
    my $self = shift;
    $self->{id} ||= $self->new_id;
    my $id = $self->id;
    die "'$id' is invalid task id"
        unless $id =~ m!^20\d\d/\d\d/\d\d/\d\d\d\d$!;
    $self->load if -e $id;
}

sub conf { $YamlTime::Conf };

has id => ( is => 'ro', required => 1 );
has mark => ( is => 'rw', default => '' );
has time => ( is => 'rw', default => '0:00' );
has task => ( is => 'rw', default => '' );
has cust => ( is => 'rw', default => '' );
has proj => ( is => 'rw', default => '' );
has tags => ( is => 'rw', default => sub{[]});
has refs => ( is => 'rw', default => sub{[]});
has note => ( is => 'rw', default => '' );

sub start {
    my ($self) = @_;
    my $mark = sprintf "%02d:%02d",
        $self->conf->now->hour,
        $self->conf->now->minute;
    $self->mark($mark);
    $self->write;
    $self->current;
}

sub stop {
    my ($self) = @_;
    die;
}

sub write {
    my ($self) = @_;
    my $template_file = YamlTime::Command->share . '/task.yaml.tt';
    my $template = io($template_file)->all;
    my $yaml = tt->render(\$template, +{ %$self });
    io($self->id)->assert->print($yaml);
}

sub current {
    my ($self) = @_;
    my $id = $self->id;
    die "No file '$id'" unless -e $id;
    unlink('_');
    symlink($id, '_');
}

sub new_id {
    my ($self) = @_;
    my $now = $self->conf->now;
    return sprintf "%4d/%02d/%02d/%02d%02d",
        $now->year,
        $now->month,
        $now->day,
        $now->hour,
        $now->minute;
}

#     my $template_file = $self->share . '/task.yaml.tt';
#     my $template = $self->read($template_file);
#     my $data = $self->prompt_task_data;
#     my $task_file = $self->new_task_file_name;
#     my $text = $self->render($template, $data);
#     $self->write($task_file, $text);
#     $self->current_link($task_file);

1;
