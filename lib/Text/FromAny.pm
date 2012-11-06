# Text::FromAny
# A module to read pure text from a vareiety of formats
# Copyright Eskild Hustvedt 2010, 2012 <zerodogg@cpan.org>
# for Portu Media & Communications
#
# This library is free software; you can redistribute it and/or modify
# it under the terms of either:
#
#    a) the GNU General Public License as published by the Free
#    Software Foundation; either version 3, or (at your option) any
#    later version, or
#    b) the "Artistic License" which comes with this Kit.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either
# the GNU General Public License or the Artistic License for more details.
#
# You should have received a copy of the Artistic License
# in the file named "COPYING.artistic".  If not, I'll be glad to provide one.
#
# You should also have received a copy of the GNU General Public License
# along with this library in the file named "COPYING.gpl". If not,
# see <http://www.gnu.org/licenses/>.
package Text::FromAny;
use Moo;
use Carp qw(carp croak);
use Try::Tiny;
use Text::Extract::Word;
use OpenOffice::OODoc 2.101;
use File::LibMagic;
use Archive::Zip;
use RTF::TEXT::Converter;
use HTML::FormatText::WithLinks;
use CAM::PDF;
use CAM::PDF::PageText;
use IPC::Open3 qw(open3);

extends 'Text::FromAny::_Core';

__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 NAME

Text::FromAny - a module to read pure text from a vareiety of formats

=head1 SYNOPSIS

    my $tFromAny = Text::FromAny->new(file => '/some/text/file');
    my $text = $tFromAny->text;

=head1 SUPPORTED FORMATS

Text::FromAny can currently read the following formats:

    Portable Document format - PDF
    Legacy/binary MSWord .doc
    OpenDocument Text
    Legacy OpenOffice.org writer
    "Office Open XML" text
    Rich text format - RTF
    (X)HTML
    Plaintext

=head1 ATTRIBUTES

Attributes can be supplied to the new constructor, as well as set by running
object->attribute(value). The "file" attribute B<MUST> be supplied during
construction.

=over

=item B<file>

The file to read. B<MUST> be supplied during construction time (and can not be
changed later). Can be any of the supported formats. If it is not of any
supported format, or an unknown format, the object will still work, though
->text will return undef.

=item B<allowGuess>

This is a boolean, defaulting to true. If Text::FromAny is unable to properly
detect the filetype it will fall back to guessing the filetype based upon
the file extension. Set this to false to disable this.

The default for I<allowGuess> is subject to change in later versions, so if
you depend on it being either on or off, you are best off explicitly requesting
that behaviour, rather than relying on the defaults.

=item B<allowExternal>

This is a boolean, defaulting to false. If the perl-based PDF reading method
fails (L<PDF::CAM>), then Text::FromAny will fall back to calling the system
L<pdftotext(1)> to get the text. L<PDF::CAM> reads most PDFs, but has troubles
with a select few, and those can be handled by L<pdftotext(1)> from the
Poppler library.

The default for I<allowExternal> is subject to change in later versions, so if
you depend on it being either on or off, you are best off explicitly requesting
that behaviour, rather than relying on the defaults.

=back

=head1 METHODS

=over

=item B<text>

Returns the text contained in the file, or undef if the file format is unknown
or unsupported.

Normally Text::FromAny will only read the file once, and then cache the text.
However if you change the value of either the allowGuess or allowExternal
attributes, Text::FromAny will re-read the file, as those can affect how a file
is read.

=item B<detectedType>

Returns the detected filetype (or undef if unknown or unsupported).
The filetype is returned as a string, and can be any of the following:

	pdf  => PDF
	odt  => OpenDocument text
	sxw  => Legacy OpenOffice.org Writer
	doc  => msword
	docx => "Open XML"
	rtf  => RTF
	txt  => Cleartext
	html => HTML (or XHTML)

=back

=head1 DIAGNOSTICS

=over

=item CAM::PDF crashed when trying to extract from page ...

This is caused by deficiencies in the L<CAM::PDF> PDF extraction library
used by Text::FromAny when it tries to read some specific PDF files. The result
is that a page will be missing from the text returned. If you set
I<allowExternal> to true and have pdftotext available then Text::FromAny will
fall back to using pdftotext in these cases (which works around the problem).

=back

=head1 BUGS AND LIMITATIONS

None known.

Please report any bugs or feature requests to
L<http://github.com/portu/Text-FromAny/issues>.

=head1 AUTHOR

Eskild Hustvedt, E<lt>zerodogg@cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010, 2012 by Eskild Hustvedt

This library is free software; you can redistribute it and/or modify
it under the terms of either:

    a) the GNU General Public License as published by the Free
    Software Foundation; either version 3, or (at your option) any
    later version, or
    b) the "Artistic License" which comes with this Kit.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either
the GNU General Public License or the Artistic License for more details.

You should have received a copy of the Artistic License
in the file named "COPYING.artistic".  If not, I'll be glad to provide one.

You should also have received a copy of the GNU General Public License
along with this library in the file named "COPYING.gpl". If not,
see <http://www.gnu.org/licenses/>.
