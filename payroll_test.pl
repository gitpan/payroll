#! /usr/bin/perl
# payroll_test.pl - Tests the Payroll module.
use strict;
use Payroll;

my $file = "test.xml";

if (defined @ARGV[0])
{
  $file=@ARGV[0];
}

#  print "Using file: $file\n\n";
my $errStr = "(payroll_test) - Error:";

my $payrollObj = Payroll->new();

my $dataObj = undef;

eval { $dataObj = $payrollObj->process(file => $file); };
#eval { $dataObj = $resultSetObj->parse(string => $xmlString); };
if ($@)
{
  die "$errStr  Eval failed: $@\n";
}

print $dataObj->generateXML;
