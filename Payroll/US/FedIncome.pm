# FedIncome.pm
# Created:  Thu Feb 14 15:24:49 CST 2002
# by JT Moree
# $Id: FedIncome.pm,v 1.9 2003/06/24 21:44:20 moreejt Exp $
#2002-2003 Xperience, Inc. www.pcxperience.com
# license:  same as perl

=head1 NAME

FedIncome

=head1 SYNOPSIS

  use Payroll::US::FedIncome;
  my $fedIncome = Payroll::US::FedIncome->new();
  if ($fedIncome->didErrorOccur())
  {
    die $fedIncome->errorMessage();
  }

=head1 DESCRIPTION

This module will calculate Federal Income Taxes for the US based on internal tables when given a gross amount

=cut

package Payroll::US::FedIncome;
use strict;
use vars qw($AUTOLOAD $VERSION @ISA @EXPORT);

require Exporter;

@ISA = qw(Exporter AutoLoader);
@EXPORT = qw();

$VERSION = '.1';

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
     $self->{periodDays} = {
        annual => 260,
        semiannual => 130,
        quarterly => 65,
        monthly => 21.67,
        semimonthly => 10.84,
        biweekly => 10,
        weekly => 5,
        daily => 1
     };
    $self->{debug} = 'no';
    $self->{dataTables} =  {
            '20010701' => {
                tables => {},
                dailyWithholdingAllowance => 11.15,
                dailyTableRows => [
                    {singleBottom =>     '0.0'    , percent =>    '0'     , marriedBottom =>    '0.00' },
                    {singleBottom =>   '10.20'    , percent =>  '.15'     , marriedBottom =>   '24.80' },
                    {singleBottom =>  '110.40'    , percent =>  '.27'     , marriedBottom =>  '191.90' },
                    {singleBottom =>  '239.20'    , percent =>  '.30'     , marriedBottom =>  '404.60' },
                    {singleBottom =>  '532.30'    , percent =>  '.35'     , marriedBottom =>  '658.50' },
                    {singleBottom => '1150.00'    , percent => '.386'     , marriedBottom => '1161.70' },
                ]
            },
            '20020101' => {
                tables => {},
                dailyWithholdingAllowance => 11.54,
                dailyTableRows => [
                    {singleBottom =>     '0.0'    , percent =>   '0'      , marriedBottom =>    '0.00' },
                    {singleBottom =>   '10.20'    , percent => '.10'      , marriedBottom =>   '24.80' },
                    {singleBottom =>   '32.90'    , percent => '.15'      , marriedBottom =>   '71.00' },
                    {singleBottom =>  '114.00'    , percent => '.27'      , marriedBottom =>  '198.30' },
                    {singleBottom =>  '249.30'    , percent => '.30'      , marriedBottom =>  '421.90' },
                    {singleBottom =>  '549.80'    , percent => '.35'      , marriedBottom =>  '680.00' },
                    {singleBottom => '1187.50'    , percent => '.386'     , marriedBottom => '1199.60' },
                ]
            },
            '20030101' => {
                tables => {},
                dailyWithholdingAllowance => 11.73,
                dailyTableRows => [
                    {singleBottom =>     '0.0'    , percent =>   '0'      , marriedBottom =>    '0.00' },
                    {singleBottom =>   '10.20'    , percent => '.10'      , marriedBottom =>   '24.80' },
                    {singleBottom =>   '32.90'    , percent => '.15'      , marriedBottom =>   '71.00' },
                    {singleBottom =>  '115.80'    , percent => '.27'      , marriedBottom =>  '201.30' },
                    {singleBottom =>  '253.50'    , percent => '.30'      , marriedBottom =>  '430.00' },
                    {singleBottom =>  '558.50'    , percent => '.35'      , marriedBottom =>  '690.80' },
                    {singleBottom => '1206.30'    , percent => '.386'     , marriedBottom => '1218.70' },
                ]
            },
            '20030601' => {
                tables => {},
                dailyWithholdingAllowance => 11.92,
                dailyTableRows => [
                    {singleBottom =>     '0.0'    , percent =>   '0'      , marriedBottom =>    '0.00' },
                    {singleBottom =>   '10.20'    , percent => '.10'      , marriedBottom =>   '30.80' },
                    {singleBottom =>   '37.30'    , percent => '.15'      , marriedBottom =>   '85.80' },
                    {singleBottom =>  '118.50'    , percent => '.25'      , marriedBottom =>  '249.00' },
                    {singleBottom =>  '263.50'    , percent => '.28'      , marriedBottom =>  '454.00' },
                    {singleBottom =>  '571.90'    , percent => '.33'      , marriedBottom =>  '713.70' },
                    {singleBottom => '1235.40'    , percent => '.35'      , marriedBottom => '1254.20' },
                ]
            },
    };
    $self->{error} = 0;
    $self->{errorString} = "";

  return $self;
}

=head2 integer isValid( gross => $gross)

        gross - floating point > 0
        date -  YYYYMMDD
        method -
        allowances - integer > 0
        period - annual, semiannual, quarterly, monthly, semimonthly, biweekly, weekly, daily
        marital - single | married
        periodDays -
        round - yes, no
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
        if (exists $args{marital} )
        {
                if ($args{marital} ne "married" && $args{marital} ne "single" )
                {  return 0; }
                else
                {  return 1; }
        }
        if (exists $args{date} )
        {
                if ($args{date} !~ /^\d{8}$/ )
                {  return 0; }
                else
                {  return 1; }
        }
        if (exists $args{allowances} )
        {
                if ($args{allowances} !~ /^\d+$/ )
                {  return 0; }
                else
                {  return 1; }
        }
        if (exists $args{round} )
        {
                if ($args{round} =~ /^(yes)|(no)$/i )
                {  return 1; }
                else
                {  return 0; }
        }
        if (exists $args{period}  )
        {
                if (exists $self->{periodDays}->{$args{period}} )
                {  return 1; }
                else
                {  return 0; }
        }

        return 0;
}

=head2 integer calculate(
         gross - total amount of pay
        date - date to be paid on.  affects tax rates  format YYYYMMDD
        method - the method to use for calculation (currently only percentage )
        allowances - federal allowances
        period - annual, semiannual, quarterly, monthly, semimonthly, biweekly, weekly, daily
        marital - single or married
        round - yes, no - defaults to yes - or should user sprintf the result.  seems that would be more efficient
  )
=cut

#        periodDays - reference to a hash containing ratios for number of days in periods. defaults to undef, hash can be overriden by the user specifying a hash ref to the same structure, different data.

sub calculate
{
        my $self = shift;
        my %args = (
                gross => "",
                date => "",
                method => "",
                allowances => "",
                period => "",
                marital => "",
                periodDays => undef,
                round => "yes",
                debug => 'no',
                @_
          );
        my $gross           = $args{gross};
        my $date           = $args{date};
        my $method            = $args{method};
        my $allowances           = $args{allowances};
        my $period           = $args{period};
        my $marital           = $args{marital};
        my $periodDays           = $self->{periodDays};
        my $round           = $args{round};
        my $withholdingAllowance = 0;
        my $modifiedGross = 0;
        my $foundDate = undef;
        my $tax = 0;
        my $base = 0;
        my $bottom = 0;
        my $percent = 0;
        $self->{debug} = $args{debug};

        if (! $self->isValid(gross => $gross))
        {  $self->setError($self->errorString . "Invalid gross: $gross\n"); return undef; }
        if (! $self->isValid(allowances => $allowances))
        {  $self->setError($self->errorString . "Invalid allowances: $allowances\n"); return undef; }
        if (! $self->isValid(marital => $marital) )
        {  $self->setError($self->errorString . "Invalid marital: $marital\n"); return undef; }
        if ($round =~ /^(yes)$/i)  # need to know round specifically
        {  $round = "yes"; }
        elsif ($round =~ /^(no)$/i)
        {  $round = "no"; }
        else
        {  $self->setError($self->errorString . "Invalid round: $round.  Use 'yes' or 'no'\n"); return undef; }
        if (! $self->isValid(period => $period ) )
        { $self->setError($self->errorString . "Invalid period: '$period'"); return undef; }
        if (! $self->isValid(date => $date))
        { $self->setError($self->errorString . "Invalid date: '$date'"); return undef; }
        else
        {  $foundDate = $self->lookupDate(date=> $date);       }
        if (not defined $foundDate)
        {  $self->setError($self->errorString . "Could not lookup date: $date\n"); return undef; }

        #step 1 - modified Gross
        $withholdingAllowance = $self->{periodDays}->{$period} * $self->{dataTables}->{$foundDate}->{dailyWithholdingAllowance};
        $modifiedGross = $gross - ($allowances * $withholdingAllowance);

        #step 2 - lookup
        if (! exists $self->{dataTables}->{$foundDate}->{tables}->{$period} || ! exists $self->{dataTables}->{$foundDate}->{tables}->{$period}->{$marital} )
        {
                my $result = $self->generateTable(period => $period, marital => $marital, date => $foundDate);
                if (not defined $result  || $result != TRUE)
                {  $self->setError($self->errorString . "Could not generate Table"); return undef;  }
        }
        if (not defined $self->{dataTables}->{$foundDate}->{tables}->{$period}->{$marital} )
        { $self->setError($self->errorString . "Error: calculate -- table $period->$marital is not defined!\n"); return undef;  }
        my $table = $self->{dataTables}->{$foundDate}->{tables}->{$period}->{$marital};
        if ($self->{debug} eq "yes")
        {
                print "\nfound:  $foundDate\n";
                print "withHAllow:  $withholdingAllowance\n";
                print "Gross  $gross\n";
                print "period $period\n";
                print "mGross:  $modifiedGross\n";
                print "marital: $marital\n";
                print "rows ";
                print scalar @{$table};
                print "\n";
                for (my $row = 0 ; $row < scalar @{$table}  ; $row++)
                {
                                print "$row";
                                print "\t   t  \t"  .  $table->[$row]->{bottom};
                                print "\t   b \t" . $table->[$row]->{base};
                                print "\t   p \t" .  $table->[$row]->{percent};
                                print "\n";
                }
                print "mGross = $modifiedGross\n\n";
        }
        for (my $row = scalar @{$table} -1; $row >= 0 ; $row--)
        {
                if ($modifiedGross >= $table->[$row]->{bottom})
                {
                        $base = $table->[$row]->{base};
                        $bottom = $table->[$row]->{bottom};
                        $percent = $table->[$row]->{percent};
                        last;#$row = 0;
                }
        }
        if ($self->{debug} eq "yes")
        {
          print "b $base,  p $percent, t $bottom\n";
        }

        $tax = ( $base + (( $modifiedGross - $bottom)  * $percent) );
        $tax *= -1 if ($tax !~ /^(0(\.00)?)$/);
        if ($round eq "no")
        {        return sprintf("%.2f",$tax);        }
        return sprintf("%.0f",$tax) . ".00"; #round to whole number
}

=head2 bool generateTable(
         period,
         marital,
         date
        )
=cut

## generated tables look like this
#tables
#          {$period =>
#                             {  single =>
#                               [
#                                       {bottom => , base => , percent => } ,
#                               ] ,
#                              married =>
#                               [
#                                       {bottom => , base => , percent => } ,
#                               ]
#                             },
#       }
sub  generateTable
{
   my $self = shift;
   my %args = (period => "", marital => "", date => "", debug => 'no', @_ );
   my $base = 0;
   my $foundDate = $args{date};
   my $bottom;
   my $period = $args{period};
   my $marital =$args{marital};
   if ($args{debug} eq "yes")
   { $self->{debug} = "yes"; }

   if (! $self->isValid(date => $foundDate) )
   {  $self->setError($self->errorString . "generateTable: Invalid date '$foundDate'"); return undef; }
   if (! $self->isValid(period =>  $period ) )
   {  $self->setError($self->errorString . "generateTable: Invalid period '$period'"); return undef; }
   my @dailyTableRows = @{$self->{dataTables}->{$foundDate}->{dailyTableRows}};

   my $table = $self->{dataTables}->{$foundDate}->{tables};
   if (not defined $dailyTableRows[0])
   { $self->setError($self->errorString . "Error:  dailyTableRows is invalid\n"); return undef;  }

   my $row;
   for ($row = 0; $row < scalar (@dailyTableRows); $row++)
   {
      $bottom = $dailyTableRows[$row]->{$marital.'Bottom'} * $self->{periodDays}->{$period} ;
      $bottom = sprintf("%.0f", $bottom);

      if ($row == 0)
      {   $base = 0;  }
      else
      {
         $base = (  ($dailyTableRows[$row -1]->{percent} *
             ($bottom - $table->{$period}->{$marital}->[$row -1]->{bottom}) )
             + $table->{$period}->{$marital}->[$row -1]->{base}  )  ;
      }
      my %tempRow = ( bottom => $bottom,
        base => $base ,
        percent => $dailyTableRows[$row]->{percent} ) ;
      #dont forget to create array single first
      push(@{$table->{$period}->{$marital}}, \%tempRow);
   } #endfor
   if ($self->{debug} eq "yes")
   {
        print "dataTables->\{" . $foundDate . "\}->\{tables\}->\{" . $period . "\}->\{" . $marital. "} with $row rows\n";
   }
   return TRUE;
}

=head2 string lookupDate (date)

        Returns the date closest to the given date that is less than or equal to it

=cut

sub lookupDate
{
  my $self = shift;
  my $found = undef;
  my %args = (date => "", @_ );

  if ( $args{date} !~ /^\d{8}$/)
  {  $self->setError($self->errorString . "Invalid format for date:'$args{date}' in lookupDate\n"); return undef;  }

  #walk over dataTables hash looking for a close match
  foreach my $current (reverse sort keys %{$self->{dataTables}} )
  {
    if ($current <= $args{date})
    {
      $found = $current;
      last;
    }
  }
  return $found;
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
                $self->{errorString} = $args{errorString};
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

1;
__END__

=
NOTE:  All data fields are accessible by specifying the object
and pointing to the data member to be modified on the
left-hand side of the assignment.
        Ex.  $obj->variable($newValue); or $value = $obj->variable;

=head1 AUTHOR

JT Moree

=head1 SEE ALSO

perl

=cut
