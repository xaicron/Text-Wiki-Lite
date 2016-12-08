requires 'Class::Accessor::Lite';
requires 'HTML::Entities';
requires 'Scalar::Util';
requires 'parent';
requires 'perl', '5.008_001';

on configure => sub {
    requires 'Module::Build::Tiny', '0.035';
};
