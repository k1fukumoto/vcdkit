require 'rake/clean'

VCDKIT=ENV['VCDKIT']
LOG="#{VCDKIT}/logs/test.log"

CLEAN.include("#{VCDKIT}/data/*",LOG,'**/*.done')
# Verbose shell command execution
verbose(true)


class Target
  attr_reader :name,:command,:done
  attr_accessor :repeat

  OPTIONS = {
    :log => "-l#{LOG}",
    :vcd => '-vtvcd.vcdc.whitecloud.jp,System,vcdadminl',
    :exops => '-T -P',
    :vc => '',
    :org => '-aAdmin',
    :vapp => '-aAdmin,\'Committed Backup - Admin\',RESTORETEST01',
    :tree => '--tree TESTALL',
  }

  def initialize(name,params={})
    @name = name
    @done = "#{name}.done"
    @repeat = params[:repeat] || 1
    opts = (params[:opts] || []).collect {|o| (o.class == Symbol)? OPTIONS[o] : o}
    @command = "#{VCDKIT}/#{name}.rb #{opts.join(' ')}"
  end

  def setup
    cmds = ([command] * @repeat).join(' && ')
    file @done do |task|
      sh "#{cmds} && touch #{@done}"
    end
  end

  def Target.setup(*targets)
    task :default => targets.collect{|t| t.done}
    targets.each {|t| t.setup}
  end
end

class DirTarget < Target
  def initialize(name,params={})
    super
    @command = "rake"
  end

  def setup
    file self.done do |task|
      sh "pushd #{name} && #{command} && popd && touch #{done}"
    end
  end
end


