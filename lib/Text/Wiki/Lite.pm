package Text::Wiki::Lite;

use strict;
use warnings;
use 5.008_001;
our $VERSION = '0.01';

use Text::Wiki::Lite::Output;
use Text::Wiki::Lite::Inline;
use Text::Wiki::Lite::Block;

sub new {
    my ($class, %opts) = @_;
    bless {
        filters        => [],
        inlines        => {},
        blocks         => {},
        escape_func    => $opts{escape_func} || \&escape_html,
    }, $class;
}

sub format {
    my ($self, $text) = @_;

    $text =~ s/\r\n/\n/msg;
    my $filters = $self->filters;
    my $inlines = $self->inlines;
    my $blocks  = $self->blocks;
    my $new_line = "\n";
    my $current_state = undef;
    my $current_stash = {};
    my $nested_states = [];
    my $parent_block;
    my $parent_stash = {};
    my $out = Text::Wiki::Lite::Output->new;
    for my $line (split(/\n/, $text), $new_line) {
#        for my $filter (@$filters) { ... }
LOOP:
        my $current_block = $blocks->{$current_state || ''};
        if (!defined $current_state || $current_block && $current_block->enabled_nest) {
            for my $key ((keys %$blocks), $self->default_block) {
                my $block = ref $key ? $key : $blocks->{$key};
                next unless $block;
                if ($current_block && $block->is_default) {
                    next unless $current_block->enabled_default_block;
                    ($line, my $ret) = $current_block->end($line, $current_stash);
                    goto ENDBLOCK if $ret;
                }
                if ($block->is_default) {
                    next unless length $line;
                }
                $current_stash = {};
                ($line, my $ret) = $block->start($line, $current_stash);
                if ($ret) {
                    if ($current_state && $current_block->enabled_nest) {
                        $parent_block = $current_block;
                        push @$nested_states, [$current_state, $current_stash];
                    }
                    $current_state = $key;
                    goto LAST if $block->foldline;
                    last;
                }
            }
        }

        my $block = ref $current_state ? $current_state : $blocks->{$current_state || ''} || undef;
        if ($block && $block->enabled_escape) {
            $line = $self->escape_func->($line);
        }
        if (($block && $block->enabled_inline) || !$current_state) {
            for my $key (keys %$inlines) {
                $line = $inlines->{$key}->parse($line);
            }
        }
        if ($block && $block->{between}) {
            $line = $block->between($line, $current_stash, sub {
                my $line = shift;
                (undef, my $ret) = $parent_block->end($line, $parent_stash);
                $current_stash->{NEXT_LINE} = $line if $ret;
                $ret;
            });
        }
ENDBLOCK:
        if ($block) {
            ($line, my $ret) = $block->end($line, $current_stash);
            if ($ret) {
                $current_state = undef;
                $current_stash = {};
                if (@$nested_states) {
                    ($current_state, $current_stash) = @{pop @$nested_states};
                }
                if (defined $current_stash->{NEXT_LINE}) {
                    if ($block->merge_pre) {
                        $line = $out->pop.$line;
                    }
                    $out->push($line);
                    $line = $current_stash->{NEXT_LINE};
                    goto LOOP;
                }
            }
        }

        LAST: $out->push($line);
    }

    return $out->join("\n");
}

sub add_filter {
    my ($self, $filter) = @_;
    push @{$self->{filters}}, $filter;
}

sub filters {
    shift->{filters};
}

sub add_inline {
    my ($self, %inlines) = @_;
    for my $key (keys %inlines) {
        $self->{inlines}{$key} = Text::Wiki::Lite::Inline->new($inlines{$key});
    }
}

sub inlines {
    shift->{inlines};
}

sub add_block {
    my ($self, %blocks) = @_;
    for my $key (keys %blocks) {
        $self->{blocks}{$key} = Text::Wiki::Lite::Block->new({ %{$blocks{$key}}, ident => $key });
    }
}

sub blocks {
    shift->{blocks};
}

sub set_default_block {
    my ($self, $block) = @_;
    $self->{default_block} = Text::Wiki::Lite::Block->new({ %$block, ident => 'DEFAULT', is_default => 1 });
}

sub default_block {
    shift->{default_block};
}

sub escape_func {
    shift->{escape_func};
}

our %_escape_table = ( '&' => '&amp;', '>' => '&gt;', '<' => '&lt;', q{"} => '&quot;', q{'} => '&#39;' );
sub escape_html {
    my $str = shift;
    return '' unless defined $str;
    $str =~ s/([&><"'])/$_escape_table{$1}/ge;
    return $str;
}
1;
__END__

=encoding utf-8

=for stopwords

=head1 NAME

Text::Wiki::Lite -

=head1 SYNOPSIS

  use Text::Wiki::Lite;

=head1 DESCRIPTION

Text::Wiki::Lite is

=head1 AUTHOR

xaicron E<lt>xaicron@cpan.orgE<gt>

=head1 COPYRIGHT

Copyright 2011 - xaicron

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=cut
