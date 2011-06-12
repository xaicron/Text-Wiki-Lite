package Text::Wiki::Lite::Block;

use strict;
use warnings;

sub new {
    my ($class, $rule) = @_;
    bless +{ %$rule }, $class;
}

sub start {
    my ($self, $line, @args) = @_;
    $self->{start}->($line, @args);
}

sub between {
    my ($self, $line, @args) = @_;
    $self->{between}->($line, @args);
}

sub end {
    my ($self, $line, @args) = @_;
    $self->{end}->($line, @args);
}

sub inline {
    shift->{inline};
}

sub escape {
    shift->{escape};
}

sub nest {
    shift->{nest};
}

sub foldline {
    shift->{foldline};
}

sub default_block {
    shift->{default_block};
}

sub merge_pre {
    shift->{merge_pre};
}

sub is_default {
    shift->{is_default};
}

1;
