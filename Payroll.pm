# Payroll.pm
# Created:  Fri May 31 12:04:36 CDT 2002
# by Xperience, Inc. (mailto:payroll@pcxperience.com)
# $Id: Payroll.pm,v 1.24 2004/08/12 21:32:45 pcxuser Exp $
#This package is released under the same license as Perl
# Copyright (c) 2002-2003 http://www.pcxperience.org  All rights reserved.

=head1 NAME

Payroll

=head1 SYNOPSIS

  use Payroll;
  
  my $file = "payrollIn.xml";
  my $string = "";  # If dynamically created or read from STDIN.

  my $payroll = Payroll->new();
  if ($payroll->didErrorOccur())
  {
    die $payroll->errorMessage();
  }

  my $result = $payroll->process(file => $file, string => $string);
  my $output = $result->generateXML();

  # now you either print it or write to a file.
  print $output;

=head1 DESCRIPTION

This is the base package for the Payroll Module.

=cut

package Payroll;
use strict;
use Payroll::XML::Parser;
use Payroll::XML::OutData;
use vars qw($AUTOLOAD $VERSION @ISA @EXPORT);

require Exporter;

@ISA = qw(Exporter AutoLoader);
@EXPORT = qw();

$VERSION = '0.8';

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

  # the cache of countries modules we have used.
  $self->{cache} = {};

  # keep a list of all countries that are supported.
  $self->{validCountries} = { "US" => 1 };

  # define the period names and how many days are in them.
  $self->{periodNames} = {"annual" => 260, "semiannual" => 130, "quarterly" => 65,
                    "monthly" => 21.67, "semimonthly" => 10.84, "biweekly" => 10,
                    "weekly" => 5, daily => 1 };

  eval { $self->{parserObj} = Payroll::XML::Parser->new(validCountries => $self->{validCountries}, periodNames => $self->{periodNames}); };
  if ($@)
  {
    die "Error:  Instantiating Payroll::XML::Parser failed!\n$@";
  }

  # do validation
  $self->{error} = !$self->isValid;
  $self->{errorString} = "";
  if ($self->{error})
  {
    $self->{errorString} = "Payroll->new() - Error!<br>\n" . $self->{errorString};
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
  my $errStr = "Payroll->isValid() - Error!<br>\n";

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

=head2 Payroll::XML::OutData process(file, string)

  Processes the xml data specified in the file or the string.  If both
  are specified, then the string takes precedence.
  
  Returns an instance of Payroll::XML::OutData which holds the perl data
  structure and can be turned into XML by calling it's generateXML()
  method.

=cut

sub process
{
  my $self = shift;
  my %args = ( file => "", string => "", @_ );
  my $file = $args{file};
  my $string = $args{string};
  my $errString = "Payroll->process()  - Error!\n";

  if (length $file > 0 && ($file ne "-" && ! -f $file))
  {
    die "$errString file = '$file' does not exist!\n";
  }
  if (length $file == 0 && length $string == 0)
  {
    die "$errString You must specify the file and/or the string!\n";
  }
  if (!exists $self->{parserObj})
  {
    die "$errString You must call new() first!\n";
  }

  my $outgoingData = Payroll::XML::OutData->new(periodNames => $self->{periodNames});

  my $incomingData = undef;
  eval { $incomingData = $self->{parserObj}->parse(file => $file, string => $string); };
  if ($@)
  {
    die "$errString  Parse of XML data failed!\n$@";
  }

  my @result = $incomingData->isValid();
  if (!$result[0])
  {
    die "$errString  Payroll File not valid!\n\n" . join("\n", @{$result[1]}) . "\n";
  }

  # at this point we have valid data and $incomingData is ready to be processed.

  my $period = $incomingData->{period};
  my $date = $incomingData->{date};
  
  $outgoingData->{period} = $period;
  $outgoingData->{date} = $date;
  $outgoingData->{genSysId} = $incomingData->{genSysId};
  $outgoingData->{startPeriod} = $incomingData->{startPeriod};
  $outgoingData->{endPeriod} = $incomingData->{endPeriod};

  # loop over all persons in the data.
  foreach my $person (@{$incomingData->{persons}})
  {
    my $id = $person->{id};
    my $marital = $person->{marital};
    
    my @items = ();  # stores all the "items" returned for this person.
    my $gross = "0.00";
    my $net = "0.00";

    # now loop over the countries this person worked in.
    foreach my $country (@{$person->{countries}})
    {
      if (!exists $self->{validCountries}->{$country->{name}})
      {
        print "Warning:  Country = '$country->{name}' is not supported!  Skipping...\n";
        next;
      }
      # see if the country Object is in the cache.
      if (!exists $self->{cache}->{$country->{name}})
      {
        eval "use Payroll::$country->{name};";
        if ($@)
        {
          die "$errString Failed to use Payroll::$country->{name}!\n$@";
        }
        eval "\$self->{cache}->{$country->{name}} = Payroll::" . $country->{name} . "->new();";
        if ($@)
        {
          die "$errString Failed to instantiate Payroll::$country->{name}!\n$@";
        }
      }

      # add the gross to our running total.
      $gross += $country->{gross};
      $net += $country->{gross};

      # now call the country modules process method
      my @result = ();
      eval { @result = $self->{cache}->{$country->{name}}->process(person => $person, period => $period, date => $date, info => $country); };
      if ($@)
      {
        die "$errString  Failed to process Payroll::$country->{name}!\n$@";
      }

      foreach my $item (@result)
      {
        if (!exists $item->{comment})
        {
          $item->{comment} = "";
        }
        push @items, $item;
        $net += $item->{value};  # only because the values are negative.
      }
    }
    
    # now handle any adjustments
    foreach my $adjustment (@{$person->{adjustments}})
    {
      push @items, { name => $adjustment->{name}, value => $adjustment->{value}, comment => $adjustment->{comment} };
      $net += $adjustment->{value};
    }

    # create the gross and net entries.
    $gross = sprintf("%.2f", $gross);
    $net = sprintf("%.2f", $net);

    push @items, { name => "gross", value => $gross, comment => "" };
    push @items, { name => "net", value => $net, comment => "" };

    # update this persons entry in the outgoingData object.
    my %person = ( id => $id, name => $person->{name}, items => \@items );
    push @{$outgoingData->{persons}}, \%person;
  }

  return $outgoingData;
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

perl(1)

=cut
