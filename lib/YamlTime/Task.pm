##
# name:      YamlTime::Task
# abstract:  YamlTime Task Object Class
# author:    Ingy döt Net <ingy@cpan.org>
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
# use XXX;

sub BUILD {
    my $self = shift;
    $self->{id} ||= $self->new_id;
    my $id = $self->id;
    die "'$id' is invalid task id"
        unless $id =~ m!^20\d\d/\d\d/\d\d/\d\d\d\d$!;
    $self->read if -e $id;
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

sub read {
    my ($self) = @_;
    my $id = $self->id;
    my $hash = YAML::XS::LoadFile($id);
    $self->{$_} = $hash->{$_}
        for keys %$hash;
}

sub write {
    my ($self) = @_;
    my $template_file = YamlTime::Command->share . '/task.yaml.tt';
    my $template = io($template_file)->all;
    my $yaml = tt->render(\$template, +{ %$self });
    io($self->id)->assert->print($yaml);
}

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
    die unless $self->in_progress;
    my $time = $self->elapsed;
    $self->time($time);
    $self->mark('');
    $self->write();
}

sub elapsed {
    my ($self) = @_;

    my $stop = DateTime->now->set_time_zone($self->conf->timezone);
    my $start = DateTime->now->set_time_zone($self->conf->timezone);

    my $mark = $self->mark;
    if ($mark) {
        $mark =~ /^(\d+):(\d+)$/ or die;
        my ($hour, $minute) = ($1, $2);
        $start->set_hour($hour);
        $start->set_minute($minute);
    }

    my $seconds = ($stop->subtract_datetime_absolute($start))->seconds;
    my $hours = int($seconds / 3600);
    $seconds %= 3600;
    my $minutes = int($seconds / 60);
    $self->time =~ /^(\d+):(\d+)$/ or die;
    $hours += $1;
    $minutes += $2;

    my $time = sprintf "%d:%02d", $hours, $minutes;
    return $time;
}

sub current {
    my ($self) = @_;
    my $id = $self->id;
    die "No file '$id'" unless -e $id;
    unlink('_');
    symlink($id, '_');
}

sub in_progress {
    my ($self) = @_;
    return !! $self->mark;
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

1;
