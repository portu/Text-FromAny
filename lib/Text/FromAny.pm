# Text::FromAny
# A module to read pure text from a vareiety of formats
# Copyright Eskild Hustvedt 2010 <zerodogg@cpan.org>
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
use Any::Moose;
use Carp qw(carp croak);
use Try::Tiny;
use Text::Extract::Word qw(get_all_text);
use OpenOffice::OODoc 2.101;
use File::LibMagic;
use Archive::Zip;
use RTF::Lexer qw(PTEXT ENBIN ENHEX CSYMB);
use HTML::FormatText::WithLinks;

our $VERSION = '0.1';

has 'file' => (
    is => 'rw',
    isa => 'Str',
    required => 1,
    );
has 'allowGuess' => (
    is => 'rw',
    isa => 'Str',
    default => 1,
    );
has '_fileType' => (
    is => 'rw',
    isa => 'Maybe[Str]',
    builder => '_getType',
    lazy => 1,
    );

# Ensure file exists during construction
sub BUILD
{
    my $self = shift;

    if(not -e $self->file)
    {
        croak($self->file.': does not exist');
    }
    elsif(not -r $self->file)
    {
        croak($self->file.': is not readable');
    }
    elsif(not -f $self->file)
    {
        croak($self->file.': is not a normal file');
    }
}

# Get the text string representing the contents of the file.
# Returns undef if the format is unknown or unsupported
sub text
{
    my $self = shift;
    my $ftype = $self->_fileType;
    
    if(not defined $ftype)
    {
        return undef;
    }

    my $text;

    try
    {
        if ($ftype eq 'pdf')
        {
            $text = $self->_getFromPDF();
        }
        elsif($ftype eq 'doc')
        {
            $text = $self->_getFromDoc();
        }
        elsif($ftype eq 'odt')
        {
            $text = $self->_getFromODT();
        }
        elsif($ftype eq 'sxw')
        {
            $text = $self->_getFromSXW();
        }
        elsif($ftype eq 'txt')
        {
            $text = $self->_getFromRaw();
        }
        elsif($ftype eq 'rtf')
        {
            $text = $self->_getFromRTF();
        }
        elsif($ftype eq 'docx')
        {
            $text = $self->_getFromDocx();
        }
        elsif($ftype eq 'html')
        {
            $text = $self->_getFromHTML();
        }
        elsif(defined $ftype)
        {
            die("Text::FromAny: Unknown detected filetype: $ftype\n");
        }

        if(defined $text)
        {
            $text =~ s/\r//g;
        }
    }
    catch
    {
        $text = undef;
    };

    return $text;
}

# Retrieve text from a PDF file
sub _getFromPDF
{
    my $self = shift;
    my $f = CAM::PDF->new($self->file);
    my $text = '';
    foreach(1..$f->numPages())
    {
        my $page = $f->getPageContentTree($_);
        $text .= CAM::PDF::PageText->render($page);
    }
    return $text;
}

# Retrieve text from a msword .doc file
sub _getFromDoc
{
    my $self = shift;
    my $text = get_all_text($self->file);
    $text =~ s/(\r|\r\n)/\n/g;
    $text =~ s/\n$//;
    return $text;
}

# Retrieve text from an "Office Open XML" file
sub _getFromDocx
{
    my $self = shift;

    my $xml = $self->_readFileInZIP('word/document.xml');
    return if not defined $xml;

    # Strip formatting newlines in the XML
    $xml =~ s/\n//g;
    # Convert XML newlines to real ones
    if(not $xml =~ s/<w:p[^>]*w:rsidRDefault[^>]+>/\n/g)
    {
        $xml =~ s/<\/w:p>/\n/g;
    }
    # Remove tags
    $xml =~ s/<[^>]+>//g;

    return $xml;
}

# Retrieve text from an Open Document text file
sub _getFromODT
{
    my $self = shift;
    my $doc = odfText(file => $self->file);
    my $xml;
    open(my $out,'>',\$xml);
    $doc->getBody->print($out);
    close($out);

    return $self->_getFromODT_SXW_XML($xml);
}

# Retrieve text from a legacy OpenOffice.org writer text file
sub _getFromSXW
{
    my $self = shift;
    my $xml = $self->_readFileInZIP('content.xml');
    return $self->_getFromODT_SXW_XML($xml);
}

# Retrieve text from an RTF file
sub _getFromRTF
{
    my $self = shift;
    my $file = $self->file;
    # ---
    # Begin code taken from File::Extract::RTF, original license is
    # the same as this library.
    # This snippet is: Copyright (c) 2005 Daisuke Maki <dmaki@cpan.org>
    #
    # The reason this is copied here, rather than simply using the CPAN
    # module is that it has troubles installing on modern platforms,
    # and it contains a load of dependencies that really is not
    # useful when this little snippet is all that's needed.
    # ---
    my $p = RTF::Lexer->new(in => $file);

    my $text;
    my $token = '';
    do {
        $token = $p->get_token;

        if ($token->[0] == ENHEX) {
            $text .= pack('H2', $token->[1]);
        } elsif ($token->[0] == CSYMB && $token->[1] =~ /^\s+$/) {
            $text .= $token->[1];
        } elsif ($token->[0] == PTEXT || $token->[0] == ENBIN) {
            $text .= $token->[1];
        }
    } until $p->is_stop_token($token);
    # ---
    # End code from File::Extract::RTF
    # ---
    return $text;
}

# Get the contents of a cleartext file
sub _getFromRaw
{
    my $self = shift;
    open(my $in,'<',$self->file) or carp("Failed to open ".$self->file.": ".$!);
    return if not $in;
    local $/ = undef;
    my $text = <$in>;
    close($in);
    return $text;
}

# Retrieve text from a HTML file
sub _getFromHTML
{
    my $self = shift;
    my $formatText = HTML::FormatText::WithLinks->new( footnote => '' );
    return $formatText->parse_file($self->file);
}

# Simple regex cleaner and formatted for ODT and SXW
sub _getFromODT_SXW_XML
{
    my $self = shift;
    my $xml  = shift;

    # Strip formatting newlines in the XML
    $xml =~ s/\n//g;
    # Strip first text:p
    $xml =~ s/<text:p[^>]*>//;
    # Convert XML newlines to real ones
    $xml =~ s/<text:p[^>]*>/\n/g;
    # Remove tags
    $xml =~ s/<[^>]*>//g;
    return $xml;
}

# Read a single file contained in a zipfile and return its contents (or undef)
sub _readFileInZIP
{
    my $self = shift;
    my $file = shift;

    my $contents;

    try
    {
        my $zip = Archive::Zip->new();
        $zip->read($self->file);
        $contents = $zip->contents($file);
    }
    catch
    {
        $contents = undef;
    };

    return $contents;
}

# Returns a filetype, one of:
# pdf => PDF
# odt => OpenDocument text
# sxw => Legacy OpenOffice.org Writer
# doc => msword
# docx => "Open XML"
# rtf => RTF
# txt => Cleartext
# 
# undef => Unable to detect/unsupported
sub _getType
{
    my $self = shift;

    my $type = $self->_getTypeFromMIME();
    if ($type)
    {
        return $type;
    }

    $type = $self->_getTypeFromMagicDesc();
    if ($type)
    {
        return $type;
    }

    $type = $self->_guessType();

    return $type;
}

# Get the filetype based upon the mimetype
sub _getTypeFromMIME
{
    my $self = shift;
    my $type;
    my %mimeMap = (
        'application/pdf' => 'pdf',
        'application/msword' => 'doc',
        'application/vnd.ms-office' => 'doc',
        'application/vnd.oasis.opendocument.text' => 'odt',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document' => 'docx',
        'application/vnd.sun.xml.writer' => 'sxw',
        'text/plain' => 'txt',
        'text/html' => 'html',
        'text/rtf' => 'rtf',
        'application/xhtml+xml' => 'html',
    );
    try
    {
        my $mime = File::LibMagic->new();
        $type = $mime->checktype_filename($self->file);
        if ($type)
        {
            chomp($type);
            $type =~ s/;.*//g;
        }
    };

    # Try to get mimetype from the zip
    if(defined $type && $type eq 'application/zip')
    {
        $type = $self->_readFileInZIP('mimetype');
        if ($type)
        {
            $type =~ s/;.*//g;
            chomp($type);
        }
    }

    if (defined $type && $mimeMap{$type})
    {
        return $mimeMap{$type};
    }
    return;
}

# Get the filetype based upon the magic file description
sub _getTypeFromMagicDesc
{
    my $self = shift;
    my $type;
    my %descrMap = (
        '^OpenOffice\.org.+Writer.+' => 'sxw',
        '^OpenDocument text$' => 'odt',
        '^PDF document.+$' => 'pdf',
    );
    try
    {
        my $mime = File::LibMagic->new();
        my $descr = $mime->describe_filename($self->file);
        if ($descr)
        {
            foreach my $r(keys(%descrMap))
            {
                if ($descr =~ /$r/)
                {
                    $type = $descrMap{$r};
                    last;
                }

            }
        }
    };
    return $type;
}

# Guess the file type
sub _guessType
{
    my $self = shift;

    return if not $self->allowGuess;

    my @guess = qw(sxw odt txt docx);

    foreach my $e (@guess)
    {
        if ($self->file =~ /\.$e$/)
        {
            return $e;
        }
    }
    return;
}

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

The file to read. B<MUST> be supplied during runtime. Can be any of the
supported formats. If it is not of any supported format, or an unknown format,
the object will still work, though ->text will return undef.

=item B<allowGuess>

This is a boolean, defaulting to true. If Text::FromAny is unable to properly
detect the filetype it will fall back to guessing the filetype based upon
the file extension. Set this to false to disable this.

The default for I<allowGuess> is subject to change in later versions, so if
you depend on it being either on or off, you are best off explicitly requesting
that behaviour, rather than relying on the defaults.

=back

=head1 METHODS

=over

=item B<text>

Returns the text contained in the file, or undef if the file format is unknown
or unsupported.

=back

=head1 BUGS AND LIMITATIONS

None known.

Please report any bugs or feature requests to
L<http://github.com/portu/Text-FromAny/issues>.

=head1 AUTHOR

Eskild Hustvedt, E<lt>zerodogg@cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 by Eskild Hustvedt

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
