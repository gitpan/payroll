# FICA.pm
# Created:  Feb 27 15:24:49 CST 2002
# by JT Moree
# $Id: FICA.pm,v 1.7 2003/09/05 19:50:06 moreejt Exp $
# License: same as perl
# 2002-2003 Xperience, Inc. www.pcxperience.com

=head1 NAME

FICA

=head1 SYNOPSIS

  use Payroll::US::FICA;
  my $fica = Payroll::US::FICA->new();
  if ($fica->didErrorOccur())
  {
    die $fica->errorMessage();
  }

=head1 DESCRIPTION

This module will calculate Social Security Taxes for the US based on internal tables when given a gross amount

=cut

package Payroll::US::FICA;
use strict;
use vars qw($AUTOLOAD $VERSION @ISA @EXPORT);

require Exporter;

@ISA = qw(Exporter AutoLoader);
@EXPORT = qw();

$VERSION = '.2';

use constant TRUE => 1;
use constant FALSE => 0;

=head1 Exported FUNCTIONS

=head2  scalar new()

        Creates a new instance of the object.

=cut

sub new
{
  my $that = shift;
  my $class = ref($that) || $that;
  my $self = bless {}, $class;
  my %args = (
              @_
              );
    $self->{debug} = 'no';
    $self->{dataTables} =  {
            '19990101' => {cap => '72000.00' , rate => '0.062'},
            '20000101' => {cap => '76200.00' , rate => '0.062'},
            '20010101' => {cap => '80400.00' , rate => '0.062'},
#            '200201101' => {cap => '80400.00' , rate => '0.062'},  #same as 2001
    };
  if (defined $args{debug})
  { $self->{debug} = $args{debug}; }
    $self->{error} = 0;
    $self->{errorString} = "";

  return $self;
}

=head2 integer isValid( gross => $gross)

        gross - floating point > 0
        date -  YYYYMMDD
        YTD - Year to date amount paid for this type of tax (float)
  )

        This method will check an argument sent in for validity.  returns 0 for no, 1 for yes .
        NOTE:  Only send one argument at a time.  If you send all you will not know which one is invalid
=cut

sub isValid
{
        my $self = shift;
        my %args =  ( @_   );
        if (exists $args{gross} )
        {
                if ($args{gross} !~ /^\d+(\.\d+)?$/)
                {  return 0; }
                else
                { return 1; }
        }
        if (exists $args{YTD} )
        {
                if ($args{YTD} !~ /^\d+(\.\d+)?$/)
                {  return 0; }
                else
                { return 1; }
        }
        if (exists $args{date} )
        {
                if ($args{date} !~ /^\d{8}$/ )
                {  return 0; }
                else
                {  return 1; }
        }

        return 0;
}

=head2 integer calculate(
         gross - total amount of pay
        date - date to be paid on.  affects tax rates  format YYYYMMDD
        YTD, total year to date
  )
=cut

sub calculate
{
        my $self = shift;
        my %args = (
                gross => "",
                date => "",
                YTD => 0,
                @_
          );
        my $answer     = 0;
        my $gross        = $args{gross};
        my $date          = $args{date};
        my $foundDate = $self->lookupDate(date=> $date);
        my $YTD          = $args{YTD};
        if (exists $args{debug} && defined $args{debug})
        {        $self->{debug} = $args{debug}; }

        if (! $self->isValid(gross => $gross))
        {  $self->setError($self->errorString . "Invalid gross: $gross\n"); return undef; }
        if (! $self->isValid(YTD => $YTD))
        {  $self->setError($self->errorString . "Invalid YTD: $YTD\n"); return undef; }
        if (not defined $foundDate)
        {  $self->setError($self->errorString . "Could not lookup date: $date\n"); return undef; }

        if ($self->{dataTables}->{$foundDate}->{cap} > 0)
        {
               if ($YTD >= $self->{dataTables}->{$foundDate}->{cap})
               {       $answer = 0;  }
               elsif ($YTD + $gross > $self->{dataTables}->{$foundDate}->{cap})
               {  #only part of the new gross amound goes over the cap
                  $answer = ($self->{dataTables}->{$foundDate}->{rate} * ($self->{dataTables}->{$foundDate}->{cap} - $YTD) ) ;
               }
               else
               {
                 $answer = $self->{dataTables}->{$foundDate}->{rate} * $gross;
               }
        }  #ignore cap if it is 0 or none of the above cases were true
        else
        {
          $answer = $self->{dataTables}->{$foundDate}->{rate} * $gross;
        }
        if ($self->{debug} eq "yes")
        {
          print "\nanswer: '$answer'\n";
          print "found: '$foundDate'\n";
          print "rate: " . $self->{dataTables}->{$foundDate}->{rate} . " \n";
          print "cap: " . $self->{dataTables}->{$foundDate}->{cap} . " \n";
          print "gross: $gross\n";
          print "YTD: $YTD\n";
        }
        $answer *= -1 if ($answer !~ /^(0(\.00)?)$/);
        return sprintf("%.2f", $answer);
}

=head2 string lookupDate ("date") or (date =>)

        Returns the date closest to the given date that is less than or equal to it

=cut

sub lookupDate
{
  my $self = shift;
  my $found = undef;
  my %args;
  my $date;
  if (scalar @_ == 1)  {
    $date = @_[0]; }
  else
  {
    %args = (date => "", @_ );
    $date = $args{date};
  }
  if ( $self->isValid(date => $date) == FALSE)
  {  $self->setError($self->errorString . "Invalid format for date:'$date' in lookupDate\n"); return undef;  }

  #check boundaries of data hash first
  my $first = $self->firstDate();
  if ( $date < $first )
  {  $self->setError($self->errorString . "Error.  Date is earlier than first date in list: $first\n"); return undef; }

  #walk over dataTables hash looking for a close match
  foreach my $current (reverse sort keys %{$self->{dataTables}} )
  {
    if ($current <= $date)
    {
      $found = $current;
      last;
    }
  }
  return $found;
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

=head2 void setError() or setError("My Error") or setError(errorString => "My Error")

        Sets error = 1 and $self->{errorString} = "My Error"
        returns nothing

=cut

sub setError
{
        my $self = shift;
        if (scalar @_ == 1)  { #print scalar @_; 
                $self->{errorString} = @_[0]; }
        else
        {
                my %args = (errorString => "", @_ );
                $self->{errorString} = $self->{errorString} . $args{errorString};
        }
        $self->{error} = 1;
}

=head2 void clearError()

        Sets $self->error = 0 and $self->{errorString} = ""
        returns nothing

=cut

sub clearError
{
        my $self = shift;
        $self->{errorString} = "";
        $self->{error} = 0;
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

=head2 string firstDate()

        This method will return the earliest date in the datatables.
        Combined with the lastDate method, you can find the date range of the data

=cut

sub firstDate
{
  my $self = shift;
  #grab keys from hash and order reverse so that the latest one is first
  return (sort keys %{$self->{dataTables}})[0] ;
}

=head2 string lastDate()

        This method will return the earliest date in the datatables.
        Combined with the firstDate method, you can find the date range of the data

=cut

sub lastDate
{
  my $self = shift;
  #grab keys from hash and order reverse so that the latest one is first
  return (reverse sort keys %{$self->{dataTables}})[0] ;
}

=head2 (rate, cap) rateCap(date)

        Returns an array containing the rate and Cap at
        the given date for Social Security Taxes.
        Returns undef on error.  0 for cap if there isn't one.

=cut
sub rateCap
{
  my $self = shift;
  my $date;
  if (scalar @_ == 1)  {
    $date = @_[0];
  }
  else 
  {  
    $self->setError("Date is missing");
    return undef;
  }
  if ($date !~ m/^(\d{8})$/)
  {
    $self->setError("Invalid date '". $date . "'");
    return undef;
  }
  $date = $self->lookupDate($date);

  return ($self->{dataTables}->{$date}->{rate}, $self->{dataTables}->{$date}->{cap});
}

=pod

NOTE:  All data fields are accessible by specifying the object
and pointing to the data member to be modified on the
left-hand side of the assignment.
        Ex.  $obj->variable($newValue); or $value = $obj->variable;

=head1 AUTHOR

JT Moree - www.pcxperience.org

=head1 SEE ALSO

perl

=cut

1;
__END__
