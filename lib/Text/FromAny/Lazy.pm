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
package Text::FromAny::Lazy;
use Moo;

extends 'Text::FromAny::_Core';

before _getFromPDF_CAMPDF => sub
{
    require CAM::PDF;
    require CAM::PDF::PageText;
};

before _getFromDoc => sub
{
    require Text::Extract::Word;
};

before _getFromODT => sub
{
    require OpenOffice::OODoc;
};

before _getFromSXW => sub
{
    require Archive::Zip;
};

before _getFromRTF => sub
{
    require RTF::TEXT::Converter;
};

before _getFromHTML => sub
{
    require HTML::FormatText::WithLinks;
};

before _getTypeFromMIME =>  sub
{
    require File::LibMagic;
    require Archive::Zip;
};

before _getTypeFromMagicDesc => sub
{
    require File::LibMagic;
};

__PACKAGE__->meta->make_immutable;
1;

