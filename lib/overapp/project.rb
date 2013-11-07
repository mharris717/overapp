module Overapp
  class Project
    include FromHash
    attr_accessor :path

    def config_body
      if FileTest.exist?("#{path}/.fstemplate")
        File.read("#{path}/.fstemplate")
      elsif FileTest.exist?("#{path}/.overapp")
        File.read("#{path}/.overapp")
      elsif FileTest.exist?("#{path}/.overlay")
        File.read("#{path}/.overlay")
      else
        raise "no config"
      end
    end

    fattr(:config) do
      res = ProjectConfig.new
      res.body = config_body
      res.load!
      res
    end

    def overapp_paths
      config.overapps + [path]
    end

    def commands(phase)
      config.commands.select { |x| x[:phase] == phase }.map { |x| x[:command] }
    end

    fattr(:overapps) do
      overapp_paths.map { |x| Files.load(x) }
    end

    fattr(:base_files) do
      if config.base
        Files.load(config.base,config.base_ops)
      else
        nil
      end
    end

    fattr(:combined_files) do
      res = base_files
      overapps.each do |overapp|
        res = res.apply(overapp)
      end
      res
    end

    def git_commit(output_path,message,init=false)
      if init
        `rm -rf #{output_path}/.git`
        ec "cd #{output_path} && git init && git config user.email johnsmith@fake.com && git config user.name 'John Smith'", :silent => true
      end
      ec "cd #{output_path} && git add . && git commit -m '#{message}'", :silent => true
    end


    def write_to!(output_path)
      commands(:before).each do |cmd|
        Overapp.ec "cd #{output_path} && #{cmd}", :silent => true
        git_commit output_path, "Ran Command: #{cmd}"
      end

      base_files.write_to! output_path

      git_commit output_path, "Base Files #{config.base}", true
      combined_files.write_to!(output_path)
      git_commit output_path, "Overapp Files #{path}"

      commands(:after).each do |cmd|
        Overapp.ec "cd #{output_path} && #{cmd}", :silent => true
        git_commit output_path, "Ran Command: #{cmd}"
      end
    end
  end

  class ProjectConfig
    include FromHash
    attr_accessor :body, :base, :base_ops
    fattr(:overapps) { [] }
    fattr(:commands) { [] }

    def base(*args)
      if args.empty?
        @base
      else
        @base = args.first
        @base_ops = args[1] || {}
      end
    end

    def overapp(name)
      self.overapps << name
    end

    def overlay(name)
      overapp(name)
    end

    def command(cmd,phase=:after)
      self.commands << {:command => cmd, :phase => phase}
    end

    def load!
      c = self
      eval(body)
    end
  end
end