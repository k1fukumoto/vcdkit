require '../common'

Target.setup(Target.new('vcd-dump',:opts => [:vcd,:vc,:log],:repeat => 2),
             Target.new('vcd-report',:opts => ['-s',:log]),
             Target.new('vcd-trend',:opts => ['--offset 0',:vcd,:log]))
