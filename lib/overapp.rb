require 'mharris_ext'

%w(files template_file thor_file project from_command).each do |f|
  load File.dirname(__FILE__) + "/overapp/#{f}.rb"
end

module Overapp
  class << self
    def with_repo_path(url)
      dir = "/tmp/#{rand(100000000000000000000)}"
      `mkdir #{dir}`
      Dir.chdir(dir) do
        `git clone #{url} .`
      end
      yield dir
    ensure
      `rm -rf #{dir}`
    end
    def with_local_path(overapp_path,&b)
      if overapp_path =~ /git/
        with_repo_path(overapp_path) do |dir|
          b[dir]
        end
      else
        yield overapp_path
      end
    end
    def write_project(overapp_path,output_path)
      with_local_path(overapp_path) do |dir|
        Overapp::Project.new(:path => dir).write_to!(output_path)
      end
    end

    def ec(cmd,ops={})
      MharrisExt.ec(cmd,ops)
    end
  end
end