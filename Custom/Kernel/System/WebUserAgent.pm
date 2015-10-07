# --
# Kernel/System/WebUserAgent.pm - a web user agent
# Copyright (C) 2001-2015 OTRS AG, http://otrs.com/
# Copyright (C) 2012-2015 Znuny GmbH, http://znuny.com/
# --
# $origin: https://github.com/OTRS/otrs/blob/e505154f2bfb3be8b817d8a02e36d7cd1aaf3420/Kernel/System/WebUserAgent.pm
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::WebUserAgent;

use strict;
use warnings;

use HTTP::Headers;
use List::Util qw(first);
use LWP::UserAgent;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Encode',
    'Kernel::System::Log',
    'Kernel::System::Main',
);

=head1 NAME

Kernel::System::WebUserAgent - a web user agent lib

=head1 SYNOPSIS

All web user agent functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object

    use Kernel::System::WebUserAgent;

    my $WebUserAgentObject = Kernel::System::WebUserAgent->new(
        Timeout => 15,                  # optional, timeout
        Proxy   => 'proxy.example.com', # optional, proxy
    );

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get database object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    $Self->{Timeout} = $Param{Timeout} || $ConfigObject->Get('WebUserAgent::Timeout') || 15;
    $Self->{Proxy}   = $Param{Proxy}   || $ConfigObject->Get('WebUserAgent::Proxy')   || '';
# ---
# Znuny4OTRS-EnhancedProxySupport
# ---
    $Self->{NoProxy} = $Param{NoProxy} || $ConfigObject->Get('WebUserAgent::NoProxy');
# ---
    return $Self;
}

=item Request()

return the content of requested URL.

Simple GET request:

    my %Response = $WebUserAgentObject->Request(
        URL => 'http://example.com/somedata.xml',
    );

Or a POST request; attributes can be a hashref like this:

    my %Response = $WebUserAgentObject->Request(
        URL  => 'http://example.com/someurl',
        Type => 'POST',
        Data => { Attribute1 => 'Value', Attribute2 => 'Value2' },
    );

alternatively, you can use an arrayref like this:

    my %Response = $WebUserAgentObject->Request(
        URL  => 'http://example.com/someurl',
        Type => 'POST',
        Data => [ Attribute => 'Value', Attribute => 'OtherValue' ],
    );

returns

    %Response = (
        Status  => '200 OK',    # http status
        Content => $ContentRef, # content of requested URL
    );

You can even pass some headers

    my %Response = $WebUserAgentObject->Request(
        URL    => 'http://example.com/someurl',
        Type   => 'POST',
        Data   => [ Attribute => 'Value', Attribute => 'OtherValue' ],
        Header => {
            Authorization => 'Basic xxxx',
            Content_Type  => 'text/json',
        },
    );

If you need to set credentials

    my %Response = $WebUserAgentObject->Request(
        URL          => 'http://example.com/someurl',
        Type         => 'POST',
        Data         => [ Attribute => 'Value', Attribute => 'OtherValue' ],
        Credentials  => {
            User     => 'otrs_user',
            Password => 'otrs_password',
            Realm    => 'OTRS Unittests',
            Location => 'ftp.otrs.org:80',
        },
    );

=cut

sub Request {
    my ( $Self, %Param ) = @_;

    # define method - default to GET
    $Param{Type} ||= 'GET';

    my $Response;

    {
        # Set HTTPS proxy for ssl requests. We must not use "local %ENV" here!
        # See http://bugs.otrs.org/show_bug.cgi?id=10577.
        # It should also not be needed as we have PerlOptions +SetupEnv in our apache
        #   configuration, and %ENV will be repopulated for every request.

        # if a proxy is set, extract it and use it as environment variables for HTTPS
        if ( $Self->{Proxy} =~ /:\/\/(.*)\// ) {
            my $ProxyAddress = $1;

# ---
# Znuny4OTRS-EnhancedProxySupport
# ---
#             # extract authentication information if needed
#             if ( $ProxyAddress =~ /(.*):(.*)@(.*)/ ) {
#                 $ENV{HTTPS_PROXY_USERNAME} = $1;
#                 $ENV{HTTPS_PROXY_PASSWORD} = $2;
#                 $ProxyAddress              = $3;
#             }
#             $ENV{HTTPS_PROXY} = $ProxyAddress;
#
#             # force Net::SSL from Crypt::SSLeay. It does SSL connections through proxies
#             # but it can't verify hostnames
#             $ENV{PERL_NET_HTTPS_SSL_SOCKET_CLASS} = "Net::SSL";
#             $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME}    = 0;

            # set no proxy if needed
            my $NoProxy;
            if ( $Self->{NoProxy} ) {
                my @Hosts = split /;/, $Self->{NoProxy};
                HOST:
                for my $Host (@Hosts) {
                    next HOST if !$Host;
                    next HOST if $Param{URL} !~ /\Q$Host\E/i;
                    $NoProxy = 1;
                    last HOST;
                }
            }

            if ( !$NoProxy ) {
                # extract authentication information if needed
                if ( $ProxyAddress =~ /(.*):(.*)@(.*)/ ) {
                    $ENV{HTTPS_PROXY_USERNAME} = $1;
                    $ENV{HTTPS_PROXY_PASSWORD} = $2;
                    $ProxyAddress              = $3;
                }
                $ENV{HTTPS_PROXY} = $ProxyAddress;

                # force Net::SSL from Crypt::SSLeay. It does SSL connections through proxies
                # but it can't verify hostnames
                $ENV{PERL_NET_HTTPS_SSL_SOCKET_CLASS} = "Net::SSL";
                $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME}    = 0;
            }
# ---
        }

        # init agent
        my $UserAgent = LWP::UserAgent->new();

        # In some scenarios like transparent HTTPS proxies, it can be neccessary to turn off
        #   SSL certificate validation.
        if ( $Kernel::OM->Get('Kernel::Config')->Get('WebUserAgent::DisableSSLVerification') ) {
            my $Loaded = $Kernel::OM->Get('Kernel::System::Main')->Require(
                'Net::SSLeay',
                Silent => 1,
            );
            if ($Loaded) {
                $UserAgent->ssl_opts(
                    verify_hostname => 0,
                );
                $UserAgent->ssl_opts(
                    SSL_verify_mode => Net::SSLeay::VERIFY_NONE(),
                );
            }
        }

        # set credentials
        if ( $Param{Credentials} ) {
            my %CredentialParams    = %{ $Param{Credentials} || {} };
            my @Keys                = qw(Location Realm User Password);
            my $AllCredentialParams = !first { !defined $_ } @CredentialParams{@Keys};

            if ($AllCredentialParams) {
                $UserAgent->credentials(
                    @CredentialParams{@Keys},
                );
            }
        }

        # set headers
        if ( $Param{Header} ) {
            $UserAgent->default_headers(
                HTTP::Headers->new( %{ $Param{Header} } ),
            );
        }

        # set timeout
        $UserAgent->timeout( $Self->{Timeout} );

        # get database object
        my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

        # set user agent
# ---
# Znuny4OTRS-EnhancedProxySupport
# ---
#         $UserAgent->agent(
#             $ConfigObject->Get('Product') . ' ' . $ConfigObject->Get('Version')
#         );
#
        my $UserAgentString   = $Kernel::OM->Get('Kernel::Config')->Get('WebUserAgentString::UserAgentString');
        $UserAgentString    ||= $ConfigObject->Get('Product') . ' ' . $ConfigObject->Get('Version');

        $UserAgent->agent($UserAgentString);
# ---
        # set proxy - but only for non-https urls, the https urls must use the environment
        # variables:
        if ( $Self->{Proxy} && $Param{URL} !~ /^https/ ) {
            $UserAgent->proxy( [ 'http', 'ftp' ], $Self->{Proxy} );
        }

# ---
# Znuny4OTRS-EnhancedProxySupport
# ---
        # set no proxy
        if ( $Self->{NoProxy} ) {
            my @Hosts = split /;/, $Self->{NoProxy};
            my @HostsCleanList;
            HOST:
            for my $Host (@Hosts) {
                next HOST if !$Host;
                push @HostsCleanList, $Host;
            }
            $UserAgent->no_proxy(@HostsCleanList);
        }
# ---

        if ( $Param{Type} eq 'GET' ) {

            # perform get request on URL
            $Response = $UserAgent->get( $Param{URL} );
        }

        else {

            # check for Data param
            if ( !IsArrayRefWithData( $Param{Data} ) && !IsHashRefWithData( $Param{Data} ) ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message =>
                        'WebUserAgent POST: Need Data param containing a hashref or arrayref with data.',
                );
                return ( Status => 0 );
            }

            # perform post request plus data
            $Response = $UserAgent->post( $Param{URL}, $Param{Data} );
        }
    }
    if ( !$Response->is_success() ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Can't perform $Param{Type} on $Param{URL}: " . $Response->status_line(),
        );
        return (
            Status => $Response->status_line(),
        );
    }

    # get the content to convert internal used charset
    my $ResponseContent = $Response->decoded_content();
    $Kernel::OM->Get('Kernel::System::Encode')->EncodeInput( \$ResponseContent );

    if ( $Param{Return} && $Param{Return} eq 'REQUEST' ) {
        return (
            Status  => $Response->status_line(),
            Content => \$Response->request()->as_string(),
        );
    }

    # return request
    return (
        Status  => $Response->status_line(),
        Content => \$ResponseContent,
    );
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<http://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
