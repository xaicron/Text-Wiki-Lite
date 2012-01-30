package Text::Wiki::Lite;

use strict;
use warnings;
use 5.008_001;
our $VERSION = '0.01';

use Text::Wiki::Lite::Output;
use Text::Wiki::Lite::Inline;
use Text::Wiki::Lite::Block;
use Scalar::Util qw(refaddr);
use Carp qw(croak);
use Class::Accessor::Lite (
    new => 0,
    ro  => [qw/inlines blocks default_block filters out/],
    rw  => [qw/escape_func/],
);

sub true  () { 1 == 1 }
sub false () { 0 == 1 }

sub new {
    my ($class, %opts) = @_;
    bless {
        filters     => [],
        inlines     => [],
        blocks      => [],
        escape_func => $opts{escape_func} || \&escape_html,
    }, $class;
}

sub format {
    my ($self, $text, $opts) = @_; # TOOD filehandle

    my $filters       = $self->filters;
    my $inlines       = $self->inlines;
    my $blocks        = $self->blocks;
    my $default_block = $self->default_block;
    my $new_line      = "\n";
    my $current_state = 0;
    my $current_stash = {};
    my $nested_states = [];
    my $parent_stash  = {};
    my $parent_block;

    my $block_map = {
        map {
            $_->{wiki} = $self;
            refaddr($_) => $_;
        } @$blocks, $default_block ? $default_block : ()
    };

    for my $inline (@$inlines) {
        $inline->{wiki} = $self;
    }

    $self->{out} = my $out = Text::Wiki::Lite::Output->new;
    $text =~ s/\r\n/\n/msg;
    for my $line (split(/\n/, $text), $new_line) {
#        chomp $line;
#        for my $filter (@$filters) { ... }
LOOP:
        my $current_block = $block_map->{$current_state};
        if (!$current_state || $current_block && $current_block->nest) {
            for my $block (@$blocks, $default_block) {
                next unless $block;
                if ($current_block && $block->is_default) {
                    next unless $current_block->default_block;
                    ($line, my $ret) = $current_block->end($line, $current_stash);
                    goto ENDBLOCK if $ret;
                }
                if ($block->is_default) {
                    next unless length $line;
                }
                $current_stash = {};
                ($line, my $ret) = $block->start($line, $current_stash);
                if ($ret) {
                    if ($current_state && $current_block->nest) {
                        ($parent_block, $current_block) = ($current_block, $block);
                        push @$nested_states, [$current_state, $current_stash];
                    }
                    $current_state = refaddr($block);
                    if ($block->foldline) {
                        if ($block->inline) {
                            for my $inline (@$inlines) {
                                $line = $inline->parse($line);
                            }
                        }
                        goto LAST
                    }
                    last;
                }
            }
        }

        my $block = $block_map->{$current_state};
        if ($block && $block->escape) {
            $line = $self->escape_func->($line);
        }
        if (($block && $block->inline) || !$current_state) {
            for my $inline (@$inlines) {
                $line = $inline->parse($line);
            }
        }
        if ($block && $block->{between}) {
            my $ret;
            if ($block->is_default) {
                for my $try (@$blocks) {
                    (undef, $ret) = $try->start($line, {});
                    last if $ret;
                }
                if ($ret) {
                    $block->set_parent_cb(sub {
                        $current_stash->{__NEXT_LINE__} = $line;
                        return true;
                    });
                    $block->between($line, $current_stash);
                    $block->remove_parent_cb;
                }
            }
            unless ($ret) {
                $line = $block->between($line, $current_stash, sub {
                    my $line = shift;
                    return unless $parent_block;
                    (undef, my $ret) = $parent_block->end($line, $parent_stash);
                    $current_stash->{__NEXT_LINE__} = $line if $ret;
                    $ret;
                });
            }
        }
ENDBLOCK:
        if ($block) {
            ($line, my $ret) = $block->end($line, $current_stash);
            if ($ret) {
                $current_state = 0;
                $current_stash = {};
                if (@$nested_states) {
                    ($current_state, $current_stash) = @{pop @$nested_states};
                }
                if (defined $current_stash->{__NEXT_LINE__}) {
                    if ($block->merge_pre) {
                        $line = $out->pop.$line;
                    }
                    $out->push($line);
                    $line = $current_stash->{__NEXT_LINE__};
                    goto LOOP;
                }
            }
        }

        LAST: $out->push($line);
    }

    my $result = $out->join("\n");
    chomp $result;
    return $result;
}

sub add_filter {
    my ($self, $filter) = @_;
    push @{$self->{filters}}, $filter;
}

sub add_inline {
    my ($self, @inlines) = @_;
    croak 'add_inline() must be key-value pair' unless @inlines % 2 == 0;
    while (@inlines) {
        my ($ident, $syntax) = splice @inlines, 0, 2;
        push @{$self->{inlines}}, Text::Wiki::Lite::Inline->new($ident, $syntax);
    }
}

sub add_block {
    my ($self, @blocks) = @_;
    croak 'add_block() must be key-value pair' unless @blocks % 2 == 0;
    while (@blocks) {
        my ($ident, $rule) = splice @blocks, 0, 2;
        push @{$self->{blocks}}, Text::Wiki::Lite::Block->new({ %$rule,
            ident => $ident,
        });
    }
}

sub set_default_block {
    my ($self, $block) = @_;
    $self->{default_block} = Text::Wiki::Lite::Block->new({ %$block,
        ident      => 'DEFAULT',
        is_default => 1,
    });
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
