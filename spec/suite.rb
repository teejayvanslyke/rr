require 'session'

class SpecSuite
  def self.def_runner(runner_name, runner_desc, program_name, suffix, opts={}, &block)
    adapter_name = opts[:adapter] || runner_name
    path = opts[:path] || runner_name
    env = opts[:env] || {}
    runner_method = "run_#{runner_name}"
    define_method(runner_method) do
      run_command(build_command(program_name, adapter_name, path, suffix, env))
    end
    runners << [runner_name, runner_desc]
  end

  def self.runners
    @runners ||= []
  end

  def self.ruby_18?
    RUBY_VERSION =~ /^1\.8/
  end

  def define_tasks(ctx)
    suite = self

    SpecSuite.runners.each do |runner_name, runner_desc|
      runner_method = "run_#{runner_name}"

      ctx.__send__ :desc, "Run #{runner_desc} tests"
      ctx.__send__ :task, :"spec:#{runner_name}" do
        session = suite.__send__(runner_method)
        if session.exit_status != 0
          raise "#{runner_desc} suite failed"
        end
      end
    end

    ctx.__send__ :desc, "Run all tests"
    ctx.__send__ :task, :spec do
      sessions = []
      SpecSuite.runners.each do |runner_name, runner_desc|
        puts "=== Running #{runner_desc} tests ================================================"
        runner_method = "run_#{runner_name}"
        sessions << suite.__send__(runner_method)
        puts
      end
      if sessions.any? {|session| session.exit_status != 0 }
        raise "Spec suite failed"
      end
    end
  end

  if ruby_18?
    def_runner :test_unit_1, 'Test::Unit 1', 'ruby', 'test'
  end

  def_runner :test_unit_2, 'Test::Unit 2', 'ruby', 'test'

  unless ruby_18?
    def_runner :minitest_4, 'MiniTest 4', 'ruby', 'test', :path => :minitest

    def_runner :minitest, 'Minitest', 'ruby', 'test'
  end

  if ruby_18?
    def_runner :rspec_1, 'RSpec 1', 'spec', 'spec'
  else
    def_runner :rspec_2, 'RSpec 2', 'rspec', 'spec',
      :env => {'SPEC_OPTS' => '--format progress'}
  end

  private

  def run_command(*parts)
    session = Session::Bash.new
    command = parts.join(" ")
    session.execute command, :out => STDOUT, :err => STDERR
    session
  end

  def build_command(program_name, adapter_name, path, suffix, env)
    env = env.merge('ADAPTER' => adapter_name)
    env.each {|k,v| ENV[k.to_s] = v.to_s }
    file_list = build_file_list(path, suffix)
    ['bundle', 'exec', program_name, *file_list]
  end

  def build_file_list(adapter_name, suffix)
    Dir[ File.expand_path("../suites/#{adapter_name}/{.,*,**}/*_#{suffix}.rb", __FILE__) ]
  end
end
