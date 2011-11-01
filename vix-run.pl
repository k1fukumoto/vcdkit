#!/usr/bin/perl

use lib qw{ blib/lib blib/auto blib/arch blib/arch/auto/VMware blib/arch/auto };

use Getopt::Std;

use VMware::Vix::Simple;
use VMware::Vix::API::Constants;

getopt("hpv");

my $hostname = $opt_h;
my $vmname = $opt_v;
my $hostport = 0;
my $username = 'root';
my $password = $opt_p;

my $script = "C:\\PROGRA~2\\VMware\\VMWARE~1\\VMWARE~1\\restart-vcddc.bat";

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
  next unless $_ =~ /$vmname/;

  print "Running VM: $_\n";
  ($err,$vm) = HostOpenVM($esx,$_,VIX_VMOPEN_NORMAL,VIX_INVALID_HANDLE);
  die $err, GetErrorText($err),"\n" if $err != VIX_OK;

  $err = VMLoginInGuest($vm,"vcdadmin",$password,0);
  die $err, GetErrorText($err),"\n" if $err != VIX_OK;

  ($err,%procinfo) = VMRunProgramInGuestEx($vm,$script,'',0,VIX_INVALID_HANDLE);
  die $err, GetErrorText($err),"\n" if $err != VIX_OK;
  print "$procinfo{'EXIT_CODE'}\n";

  ReleaseHandle($vm);
}

HostDisconnect($esx);

