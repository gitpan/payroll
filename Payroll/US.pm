# US.pm
# Created:  Fri May 31 12:04:36 CDT 2002
# by Xperience, Inc. (mailto:payroll@pcxperience.com)
# $Id: US.pm,v 1.12 2003/06/24 21:44:20 moreejt Exp $
#This package is released under the same license as Perl
# Copyright (c) 2002-2003 http://www.pcxperience.org  All rights reserved.

=head1 NAME

Payroll::US

=head1 SYNOPSIS

  use Payroll::US;

  my $usPayroll = Payroll::US->new();
  if ($usPayroll->didErrorOccur())
  {
    die $usPayroll->errorMessage();
  }

  my $result = Payroll::XML::OutData->new(periodNames => \%periodNames);
  my @result = ();

  eval { @result = $usPayroll->process(person => $person, date => $date, period => $period,
                             info => \%countryInfo);
  if ($@)
  {
    die "$@";
  }

=head1 DESCRIPTION

This is the base package for the Payroll::US Modules.

=cut

package Payroll::US;
use strict;
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

  # the cache of state modules we have used.
  $self->{stateCache} = {};
  
  # the cache of FedIncome, Medicare, FICA modules we have used.
  $self->{generalCache} = {};

  # do validation
  $self->{error} = !$self->isValid;
  $self->{errorString} = "";
  if ($self->{error})
  {
    $self->{errorString} = "Payroll::US->new() - Error!<br>\n" . $self->{errorString};
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
  my $errStr = "Payroll::US->isValid() - Error!<br>\n";

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

=head2 @items process(person, date, period, info, round)

  info contains the information related to this country for the specified person.
  person represents the person object in the Data structure.
  date is the date specified in the XML document.
  period is the period specified in the XML document.
  round specifies whether to round the result or not.
  
  Returns: the items array of name,value entries created.

=cut

sub process
{
  my $self = shift;
  my %args = ( person => undef, date => "", period => "daily", info => undef, round => "yes", @_ );
  my $person = $args{person};
  my $date = $args{date};
  my $period = $args{period};
  my $info = $args{info};
  my $round = $args{round};
  my $errString = "Payroll::US->process()  - Error!\n";
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
    die "$errString  round = '$round' is invalid!\n";
  }

  foreach my $module ("FedIncome", "Medicare", "FICA", "Mileage")
  {
    # see if the Object is in the cache.
    if (!exists $self->{generalCache}->{$module})
    {
      eval "use Payroll::US::$module;";
      if ($@)
      {
        die "$errString Failed to use Payroll::US::$module!\n$@";
      }
      eval "\$self->{generalCache}->{$module} = Payroll::US::" . $module . "->new();";
      if ($@)
      {
        die "$errString Failed to instantiate Payroll::US::$module!\n$@";
      }
    }
  }

  # now calculate the FedIncome
  my $federal = $self->{generalCache}->{FedIncome}->calculate(gross => $info->{gross},
                date => $date, period => $period, method => $info->{method},
                allowances => $info->{allow}, marital => $person->{marital},
                round => $round);
  if (!defined $federal)
  {
    die "$errString Calculating US Federal witholding failed!\n" . $self->{generalCache}->{FedIncome}->errorMessage();
  }
  $federal -= $info->{withHold};
  $federal = sprintf("%.0f", $federal) . ".00" if ($round eq "yes");
  $items[0] = { name => "US Federal", value => $federal };
  $federal *= -1 if ($federal !~ /^(0(\.00)?)$/);
  #print "Federal = '$federal'\n";

  # now calculate the Medicare
  my $medicare = $self->{generalCache}->{Medicare}->calculate(gross => $info->{gross},
                 date => $date, YTD => $info->{grossYTD});
  if (!defined $medicare)
  {
    die "$errString Calculating US Medicare witholding failed!\n" . $self->{generalCache}->{Medicare}->errorMessage();
  }
  $items[1] = { name => "US Medicare", value => $medicare };
  $medicare *= -1 if ($medicare !~ /^(0(\.00)?)$/);
  #print "Medicare = '$medicare'\n";

  # now calculate the FICA
  my $fica = $self->{generalCache}->{FICA}->calculate(gross => $info->{gross},
             date => $date, YTD => $info->{grossYTD});
  if (!defined $fica)
  {
    die "$errString Calculating US FICA witholding failed!\n" . $self->{generalCache}->{FICA}->errorMessage();
  }
  $items[2] = { name => "US FICA", value => $fica };
  $fica *= -1 if ($fica !~ /^(0(\.00)?)$/);
  #print "FICA = '$fica'\n";

  # loop over all states in the info object.
  foreach my $state (@{$info->{states}})
  {
    # see if the state Object is in the cache.
    if (!exists $self->{stateCache}->{$state->{name}})
    {
      eval "use Payroll::US::$state->{name};";
      if ($@)
      {
        die "$errString Failed to use Payroll::US::$state->{name}!\n$@";
      }
      eval "\$self->{stateCache}->{$state->{name}} = Payroll::US::" . $state->{name} . "->new();";
      if ($@)
      {
        die "$errString Failed to instantiate Payroll::US::$state->{name}!\n$@";
      }
    }

    # now call the state modules process method
    my @stateItems = ();
    eval { @stateItems = $self->{stateCache}->{$state->{name}}->process(person => $person, date => $date,
                         period => $period, info => $state, federal => $federal, fYTD => $info->{federalYTD},
                         round => $round); };
    if ($@)
    {
      die "$errString  Failed to process Payroll::US::$state->{name}!\n$@";
    }

    foreach my $item (@stateItems)
    {
      push @items, $item;
    }
  }
  
  # now do any Mileage work
  if ($info->{mileage})
  {
    my $mileage = $self->{generalCache}->{Mileage}->calculate(miles => $info->{mileage},
             date => $date);
    if (!defined $mileage)
    {
      die "$errString Calculating US Mileage reimbursement failed!\n" . $self->{generalCache}->{Mileage}->errorMessage();
    }
    $mileage = sprintf("%.2f", $mileage);
    push @items, { name => "US Mileage", value => $mileage };
  }

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

perl(1), Payroll(3)

=cut
