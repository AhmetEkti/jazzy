require 'optparse'
require 'pathname'
require 'uri'

require 'jazzy/doc'
require 'jazzy/podspec_documenter'
require 'jazzy/source_declaration/access_control_level'

module Jazzy
  # rubocop:disable Metrics/ClassLength
  class Config

    class Attribute
      attr_reader :name
      attr_reader :description
      attr_reader :command_line
      attr_reader :parse

      def initialize(name, description: nil, command_line: nil, parse: ->(x) { x })
        @name = name
        @description = description
        @command_line = command_line
        @parse = parse
      end

      def get(config)
        config.method(name).call
      end

      def set(config, val)
        config.method("#{name}=").call(parse.call(val))
      end

      def attach_to_option_parser(config, opt)
        if command_line
          opt.on *Array(command_line), *Array(description) do |val|
            set(config, val)
          end
        end
      end
    end

    def self.config_attr(name, **opts)
      attr_accessor name
      @config_attrs ||= []
      @config_attrs << Attribute.new(name, **opts)
    end

    # ──────── Build ────────

    config_attr :output,
      description: 'Folder to output the HTML docs to',
      command_line: ['-o', '--output FOLDER'],
      parse: ->(o) { Pathname(o) }

    config_attr :clean,
      command_line: ['-c', '--[no-]clean'],
      description: ['Delete contents of output directory before running. ',
                    'WARNING: If --output is set to ~/Desktop, this will '\
                    'delete the ~/Desktop directory.']

    config_attr :xcodebuild_arguments,
      command_line: ['-x', '--xcodebuild-arguments arg1,arg2,…argN', Array],
      description: 'Arguments to forward to xcodebuild'

    config_attr :sourcekitten_sourcefile,
      command_line: ['-s', '--sourcekitten-sourcefile FILEPATH'],
      description: 'File generated from sourcekitten output to parse',
      parse: ->(s) { Pathname(s) }

    config_attr :source_directory,
      command_line: ['--source-directory DIRPATH'],
      description: 'The directory that contains the source to be documented',
      parse: ->(sd) { Pathname(sd) }

    config_attr :excluded_files,
      command_line: ['-e', '--exclude file1,file2,…fileN', Array],
      description: 'Files to be excluded from documentation',
      parse: ->(files) do
        files.map { |f| File.expand_path(f) }
      end

    config_attr :swift_version,
      command_line: ['--swift-version VERSION']

    # ──────── Metadata ────────

    config_attr :author_name,
      command_line: ['-a', '--author AUTHOR_NAME'],
      description: 'Name of author to attribute in docs (e.g. Realm)'

    config_attr :author_url,
      command_line: ['-u', '--author_url URL'],
      description: 'Author URL of this project (e.g. http://realm.io)',
      parse: ->(u) { URI(u) }

    config_attr :module_name,
      command_line: ['-m', '--module MODULE_NAME'],
      description: 'Name of module being documented. (e.g. RealmSwift)'

    config_attr :version,
      command_line: ['--module-version VERSION'],
      description: 'module version. will be used when generating docset'

    config_attr :copyright,
      command_line: ['--copyright COPYRIGHT_MARKDOWN'],
      description: 'copyright markdown rendered at the bottom of the docs pages'

    config_attr :readme_path,
      command_line: ['--readme FILEPATH'],
      description: 'The path to a markdown README file',
      parse: ->(rp) { Pathname(rp) }

    config_attr :podspec,
      command_line: ['--podspec FILEPATH'],
      parse: ->(ps) do
        PodspecDocumenter.configure(self, Pathname(ps))
      end

    config_attr :docset_platform

    config_attr :docset_icon,
      command_line: ['--docset-icon FILEPATH'],
      parse: ->(di) { Pathname(di) }

    config_attr :docset_path,
      command_line: ['--docset-path DIRPATH'],
      description: 'The relative path for the generated docset'

    # ──────── URLs ────────

    config_attr :root_url,
      command_line: ['-r', '--root-url URL'],
      description: 'Absolute URL root where these docs will be stored',
      parse: ->(r) { URI(r)}

    config_attr :dash_url,
      command_line: ['-d', '--dash_url URL'],
      description: 'Location of the dash XML feed '\
                    'e.g. http://realm.io/docsets/realm.xml)',
      parse: ->(d) { URI(d) }

    config_attr :github_url,
      command_line: ['-g', '--github_url URL'],
      description: 'GitHub URL of this project (e.g. '\
                   'https://github.com/realm/realm-cocoa)',
      parse: ->(g) { URI(g) }

    config_attr :github_file_prefix,
      command_line: ['--github-file-prefix PREFIX'],
      description: 'GitHub URL file prefix of this project (e.g. '\
                   'https://github.com/realm/realm-cocoa/tree/v0.87.1)'

    # ──────── Doc generation options ────────

    config_attr :min_acl,
      command_line: ['--min-acl [private | internal | public]'],
      description: 'minimum access control level to document '\
                    'default is public)',
      parse: ->(acl) do
        case acl
          when 'private'  then SourceDeclaration::AccessControlLevel.private
          when 'internal' then SourceDeclaration::AccessControlLevel.internal
        end
      end

    config_attr :skip_undocumented,
      command_line: ['--[no-]skip-undocumented'],
      description: "Don't document declarations that have no documentation '\
                  'comments."

    config_attr :hide_documentation_coverage,
      command_line: ['--[no-]hide-documentation-coverage'],
      description: "Hide \"(X\% documented)\" from the generated documents"

    config_attr :custom_categories

    config_attr :template_directory,
      command_line: ['t', '--template-directory DIRPATH'],
      description: 'The directory that contains the mustache templates to use',
      parse: ->(td) { Pathname(td) }

    config_attr :assets_directory,
      command_line: ['--assets-directory DIRPATH'],
      description: 'The directory that contains the assets (CSS, JS, images) '\
                   'used by the templates',
      parse: ->(ad) { Pathname(ad) }

    def initialize
      PodspecDocumenter.configure(self, Dir['*.podspec{,.json}'].first)
      self.output = Pathname('docs')
      self.xcodebuild_arguments = []
      self.author_name = ''
      self.module_name = ''
      self.author_url = URI('')
      self.clean = false
      self.docset_platform = 'jazzy'
      self.version = '1.0'
      self.min_acl = SourceDeclaration::AccessControlLevel.public
      self.skip_undocumented = false
      self.hide_documentation_coverage = false
      self.source_directory = Pathname.pwd
      self.excluded_files = []
      self.custom_categories = {}
      self.template_directory = Pathname(__FILE__).parent + 'templates'
      self.swift_version = '2.0'
      self.assets_directory = Pathname(__FILE__).parent + 'assets'
    end

    def template_directory=(template_directory)
      @template_directory = template_directory
      Doc.template_path = template_directory
    end

    # rubocop:disable Metrics/MethodLength
    def self.parse!
      config = new
      OptionParser.new do |opt|
        opt.banner = 'Usage: jazzy'
        opt.separator ''
        opt.separator 'Options'

        @config_attrs.each do |attr|
          attr.attach_to_option_parser(config, opt)
        end

        opt.on('-v', '--version', 'Print version number') do
          puts 'jazzy version: ' + Jazzy::VERSION
          exit
        end

        opt.on('-h', '--help', 'Print this help message') do
          puts opt
          exit
        end
      end.parse!

      if config.root_url
        config.dash_url ||= URI.join(r, "docsets/#{config.module_name}.xml")
      end

      config
    end

    def self.parse_config_file(file)
      case File.extname(file)
        when '.json'         then JSON.parse(File.read(file))
        when '.yaml', '.yml' then YAML.load(File.read(file))
        else raise "Config file must be .yaml or .json, but got #{file.inspect}"
      end
    end

    #-------------------------------------------------------------------------#

    # @!group Singleton

    # @return [Config] the current config instance creating one if needed.
    #
    def self.instance
      @instance ||= new
    end

    # Sets the current config instance. If set to nil the config will be
    # recreated when needed.
    #
    # @param  [Config, Nil] the instance.
    #
    # @return [void]
    #
    class << self
      attr_writer :instance
    end

    # Provides support for accessing the configuration instance in other
    # scopes.
    #
    module Mixin
      def config
        Config.instance
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end
