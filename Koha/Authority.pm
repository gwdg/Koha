package Koha::Authority;

# Copyright 2012 C & P Bibliography Services
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

=head1 NAME

Koha::Authority - class to encapsulate authority records in Koha

=head1 SYNOPSIS

Object-oriented class that encapsulates authority records in Koha.

=head1 DESCRIPTION

Authority data.

=cut

use strict;
use warnings;
use C4::Context;
use MARC::Record;
use MARC::File::XML;
use C4::Charset;
use Koha::Util::MARC;

use base qw(Koha::MetadataRecord);

__PACKAGE__->mk_accessors(qw( authid authtype ));

=head2 new

    my $auth = Koha::Authority->new($record);

Create a new Koha::Authority object based on the provided record.

=cut

sub new {
    my $class = shift;
    my $record = shift;

    my $self = $class->SUPER::new(
        {
            'record' => $record,
            'schema' => lc C4::Context->preference("marcflavour")
        }
    );

    bless $self, $class;
    return $self;
}


=head2 get_from_authid

    my $auth = Koha::Authority->get_from_authid($authid);

Create the Koha::Authority object associated with the provided authid.
Note that this routine currently retrieves a MARC record because
authorities in Koha are MARC records by definition. This is an
unfortunate but unavoidable fact.

=cut

sub get_from_authid {
    my $class = shift;
    my $authid = shift;
    my $marcflavour = lc C4::Context->preference("marcflavour");

    my $dbh=C4::Context->dbh;
    my $sth=$dbh->prepare("select authtypecode, marcxml from auth_header where authid=?");
    $sth->execute($authid);
    my ($authtypecode, $marcxml) = $sth->fetchrow;
    my $record=eval {MARC::Record->new_from_xml(StripNonXmlChars($marcxml),'UTF-8',
        (C4::Context->preference("marcflavour") eq "UNIMARC"?"UNIMARCAUTH":C4::Context->preference("marcflavour")))};
    return if ($@);
    $record->encoding('UTF-8');

    # NOTE: GuessAuthTypeCode has no business in Koha::Authority, which is an
    #       object-oriented class. Eventually perhaps there will be utility
    #       classes in the Koha:: namespace, but there are not at the moment,
    #       so this shim seems like the best option all-around.
    require C4::AuthoritiesMarc;
    $authtypecode ||= C4::AuthoritiesMarc::GuessAuthTypeCode($record);

    my $self = $class->SUPER::new( { authid => $authid,
                                     authtype => $authtypecode,
                                     schema => $marcflavour,
                                     record => $record });

    bless $self, $class;
    return $self;
}

=head2 get_from_breeding

    my $auth = Koha::Authority->get_from_authid($authid);

Create the Koha::Authority object associated with the provided authid.

=cut

sub get_from_breeding {
    my $class = shift;
    my $import_record_id = shift;
    my $marcflavour = lc C4::Context->preference("marcflavour");

    my $dbh=C4::Context->dbh;
    my $sth=$dbh->prepare("select marcxml from import_records where import_record_id=? and record_type='auth';");
    $sth->execute($import_record_id);
    my $marcxml = $sth->fetchrow;
    my $record=eval {MARC::Record->new_from_xml(StripNonXmlChars($marcxml),'UTF-8',
        (C4::Context->preference("marcflavour") eq "UNIMARC"?"UNIMARCAUTH":C4::Context->preference("marcflavour")))};
    return if ($@);
    $record->encoding('UTF-8');

    # NOTE: GuessAuthTypeCode has no business in Koha::Authority, which is an
    #       object-oriented class. Eventually perhaps there will be utility
    #       classes in the Koha:: namespace, but there are not at the moment,
    #       so this shim seems like the best option all-around.
    require C4::AuthoritiesMarc;
    my $authtypecode = C4::AuthoritiesMarc::GuessAuthTypeCode($record);

    my $self = $class->SUPER::new( {
                                     schema => $marcflavour,
                                     authtype => $authtypecode,
                                     record => $record });

    bless $self, $class;
    return $self;
}

sub authorized_heading {
    my ($self) = @_;
    if ($self->schema =~ m/marc/) {
        return Koha::Util::MARC::getAuthorityAuthorizedHeading($self->record, $self->schema);
    }
    return;
}

1;
