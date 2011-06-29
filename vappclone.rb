require 'VCD'
require 'pp'

vcd = VCD.new()
vdc = vcd.orgs['Admin'].vdcs['Admin']
src = vdc.vapps['TESTBACKUP-01']
vdc.cloneVApp(src,'new vapp-2')
