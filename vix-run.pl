#!/usr/bin/perl

use lib qw{ blib/lib blib/auto blib/arch blib/arch/auto/VMware blib/arch/auto };

use strict;
use Getopt::Std;

use VMware::Vix::Simple;
use VMware::Vix::API::Constants;

my %args;
getopts("hpv",\%args);

my $hostname = %args{h}
my $hostport = 0;
my $username = 'root';
my $password = %args{p}

my $err;
my $esx;
my $vm;
my @vms;
my %procinfo;

($err, $esx) = HostConnect(VIX_API_VERSION, 
			   VIX_SERVICEPROVIDER_VMWARE_VI_SERVER,
			   "https://$hostname/sdk",
			   443, # ignored
			   $username,
			   $password,
			   0, VIX_INVALID_HANDLE);
die "Connect failed, $err ", GetErrorText($err), "\n" if $err != VIX_OK;

@vms = FindRunningVMs($esx, 100);
$err = shift @vms;
die "Error $err finding running VMs ", GetErrorText($err),"\n" if $err != VIX_OK;

foreach (@vms) {
  print "Running VM: $_\n";
  ($err,$vm) = HostOpenVM($esx,$_,VIX_VMOPEN_NORMAL,VIX_INVALID_HANDLE);
  die $err, GetErrorText($err),"\n" if $err != VIX_OK;

  $err = VMLoginInGuest($vm,"Administrator","vmware1!",0);
  die $err, GetErrorText($err),"\n" if $err != VIX_OK;

  ($err,%procinfo) = VMRunProgramInGuestEx
    ($vm,"c:\\restart_service.bat",'',0,VIX_INVALID_HANDLE);
  die $err, GetErrorText($err),"\n" if $err != VIX_OK;
  print "$procinfo{'EXIT_CODE'}\n";

  ReleaseHandle($vm);
}

HostDisconnect($esx);

