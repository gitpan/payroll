# MO.pm
# Created:  Fri May 31 12:04:36 CDT 2002
# by Xperience, Inc. (mailto:admin@pcxperience.com)
# $Id: MO.pm,v 1.9 2003/06/24 21:44:20 moreejt Exp $
# Copyright (c) 2002-2003 http://www.pcxperience.org  All rights reserved.
# License: same as perl

=head1 NAME

Payroll::US::MO

=head1 SYNOPSIS

  use Payroll::US::MO;

  my $moPayroll = Payroll::US::MO->new();
  if ($moPayroll->didErrorOccur())
  {
    die $moPayroll->errorMessage();
  }

  my $result = Payroll::XML::OutData->new(periodNames => \%periodNames);
  my @result = ();

  eval { @result = $moPayroll->process(person => $person, date => $date, period => $period,
                             info => \%countryInfo, federal => $federal, fYTD => $fYTD);
  if ($@)
  {
    die "$@";
  }

=head1 DESCRIPTION

This is the base package for the Payroll::US::MO Modules.

=cut

package Payroll::US::MO;
use strict;
use Payroll::US::MO::StateIncome;
use vars qw($AUTOLOAD $VERSION @ISA @EXPORT);

require Exporter;

@ISA = qw(Exporter AutoLoader);
@EXPORT = qw();

$VERSION = '0.1';

my %trueFalse = ( 1 => "true", 0 => "false" );
my %falseTrue = ( "true" => 1, "false" => 0 );

=head1 Exported FUNCTIONS

=pod

=head2  scalar new()

        Creates a new instance of the object.
        takes:

=cut

sub new
{
  my $that = shift;
  my $class = ref($that) || $that;
  my $self = bless {}, $class;
  my %args = (
              @_
              );

  # the cache of state related modules we have used.
  $self->{moduleCache} = {};

  # do validation
  $self->{errorString} = "";
  $self->{error} = !$self->isValid;
  if ($self->{error})
  {
    $self->{errorString} = "Payroll::US::MO->new() - Error!<br>\n" . $self->{errorString};
  }

  return $self;
}

=head2 bool isValid(void)

        Returns 0 or 1 to indicate if the object is valid.  The error will be available via errorMessage().

=cut

sub isValid
{
  my $self = shift;
  my $error = 0;
  my $errorString = "";
  my $errStr = "Payroll::US::MO->isValid() - Error!<br>\n";

  # do validation code here.

  $self->{error} = $error;
  $self->{errorString} = $errStr if $error;
  $self->{errorString} .= $errorString;

  return !$error;
}

sub DESTROY
{
  my $self = shift;
}

sub AUTOLOAD
{
  my $self = shift;
  my $type = ref($self) || die "$self is not an object";
  my $name = $AUTOLOAD;
  $name =~ s/.*://;	# strip fully-qualified portion
  unless (exists $self->{$name})
  {
    die "Can't access `$name' field in object of class $type";
  }
  if (@_)
  {
    return $self->{$name} = shift;
  }
  else
  {
    return $self->{$name};
  }
}

=head2 void setError(errorString)

        Sets error = 1 and $self->{errorString} = errorString.
        returns nothing

=cut

sub setError
{
  my $self = shift;
  if (scalar @_ == 1)  { #print scalar @_; 
    $self->{errorString} = @_[0]; }
  else
  {
    my %args = (errorString => "", errStr => "", @_ );
    $self->{errorString} = $args{errorString} . $args{errStr};
  }
  $self->{error} = 1;
}

=head2 scalar didErrorOccur(void)

        Returns the value of error.

=cut

sub didErrorOccur
{
  my $self = shift;

  return $self->{error};
}

=head2 scalar errorMessage(void)

        Returns the value of errorString.

=cut

sub errorMessage
{
  my $self = shift;

  return $self->{errorString};
}

=head2 @items process(person, date, period, info, federal, fYTD, round)

  info contains the information related to this country for the specified person.
  person represents the person object in the Data structure.
  date is the date specified in the XML document.
  period is the period specified in the XML document.
  federal is the calculated federal taxes.
  fYTD is the currently withheld federal YTD taxes.
  round indicates if we are to round the results.

  Returns: the items array of name,value entries created.

=cut

sub process
{
  my $self = shift;
  my %args = ( person => undef, date => "", period => "daily", info => undef, federal => "0", fYTD => "0", round => "yes", @_ );
  my $person = $args{person};
  my $date = $args{date};
  my $period = $args{period};
  my $info = $args{info};
  my $federal = $args{federal};
  my $fYTD = $args{fYTD};
  my $round = $args{round};
  my $errString = "Payroll::US::MO->process()  - Error!\n";
  my @items = ();

  if (!defined $person)
  {
    die "$errString  person not defined!\n";
  }
  if ($date !~ /^(\d{8})$/)
  {
    die "$errString  date = '$date' is invalid!\n";
  }
  if (length $period == 0)
  {
    die "$errString period must be specified!\n";
  }
  if (!defined $info)
  {
    die "$errString  info not defined!\n";
  }
  if ($round !~ /^(yes|no)$/)
  {
    die "$errString round = '$round' is invalid!\n";
  }
  if ($federal !~ /^(\d+(\.\d+)?)$/)
  {
    die "$errString federal = '$federal' is invalid!\n";
  }
  if ($fYTD !~ /^(\d+\.\d+)$/)
  {
    die "$errString fYTD = '$fYTD' is invalid!\n";
  }

  # now calculate the StateIncome
  if (!exists $self->{moduleCache}->{StateIncome})
  {
    eval "\$self->{moduleCache}->{StateIncome} = Payroll::US::MO::StateIncome->new();";
    if ($@)
    {
      die "$errString Failed to instantiate Payroll::US::MO::StateIncome!\n$@";
    }
  }
  
  #print "US MO:  gross = '$info->{gross}', federal => '$federal'\n";

  my $answer = $self->{moduleCache}->{StateIncome}->calculate(gross => $info->{gross},
               date => $date, method => $info->{method}, allowances => $info->{allow},
               period => $period, marital => $person->{marital}, federal => $federal,
               fYTD => $fYTD, round => $round);
  if (!defined $answer)
  {
    die "$errString " . $self->{moduleCache}->{StateIncome}->errorMessage;
  }
  $answer -= $info->{withHold};
  $answer = sprintf("%.0f", $answer) . ".00" if ($round eq "yes");
  $items[0] = { name => "US MO", value => $answer };

  # we should handle locals here, but am just going to ignore them for now.

  return @items;
}

1;
__END__

=
NOTE:  All data fields are accessible by specifying the object
and pointing to the data member to be modified on the
left-hand side of the assignment.
        Ex.  $obj->variable($newValue); or $value = $obj->variable;

=head1 AUTHOR

Xperience, Inc. (mailto:admin@pcxperience.com)

=head1 SEE ALSO

perl(1), Payroll(3), Payroll::US(3)

=cut
