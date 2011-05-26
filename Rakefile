require 'rake'
require 'rake/clean'
require 'rake/testtask' 
require 'rake/gempackagetask'
require 'rake/packagetask'
require 'rubygems'

if Gem.required_location("hanna", "hanna/rdoctask.rb")
  puts "using Hanna RDoc template"
  require 'hanna/rdoctask'
else
  puts "using standard RDoc template"
  require 'rake/rdoctask'
end

spec = Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.summary = "Simple Declarative Language for Ruby library"
  s.name = 'sdl4r'
  s.version = '0.9.7'
  s.requirements << 'none'
  s.require_path = 'lib'
  s.authors = ['Philippe Vosges', 'Daniel Leuck']
  s.email = 'sdl-users@ikayzo.org'
  s.rubyforge_project = 'sdl4r'
  s.homepage = 'http://www.ikayzo.org/confluence/display/SDL/Home'
  s.files = FileList['lib/sdl4r.rb', 'lib/sdl4r/**/*.rb', 'bin/*', '[A-Z]*', 'test/**/*', 'doc/**/*'].to_a
  s.test_files = FileList[ 'test/**/*test.rb' ].to_a
  s.description = <<EOF
  The Simple Declarative Language provides an easy way to describe lists, maps,
  and trees of typed data in a compact, easy to read representation.
  For property files, configuration files, logs, and simple serialization
  requirements, SDL provides a compelling alternative to XML and Properties
  files.
EOF
end

Rake::PackageTask.new(spec.name, spec.version) do |p|
  p.need_zip = true
  p.need_tar = false
  p.need_tar_gz = false
  p.need_tar_bz2 = false
  #p.package_files.include("lib/sdl4r/**/*.rb")

  # If "zip" is not available, we try 7-zip.
  system("zip")
  p.zip_command = "7z a -tzip" if $?.exitstatus == 127
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_zip = true
  pkg.need_tar = true
end

Rake::RDocTask.new do |rd|
  files = ['README', 'LICENSE', 'CHANGELOG', 'lib/**/*.rb', 'doc/**/*.rdoc', 'test/**/*.rb']
  rd.main = 'README'
  rd.rdoc_files.include(files)
  rd.rdoc_files.exclude("lib/scratchpad.rb")
  rd.rdoc_dir = "doc"
  rd.title = "RDoc: Simple Declarative Language for Ruby"
  rd.options << '--charset' << 'utf-8'
  rd.options << '--line-numbers'
  rd.options << '--inline-source'
end

gen_rubyforge = task :gen_rubyforge => [:rdoc] do
  # Modify the front page of the Rubyforge front page
  File.open("doc/files/CHANGELOG.html", "r:UTF-8") do |f|
    changelog = f.read
    if changelog =~ /(<div id='content'>.*?)<div id='footer-push'>/im
      changelog = $1
      new_front_page = File.open("rubyforge/index.html", "r:UTF-8") do |f2|
        f2.read.gsub(
          /<!-- CHANGELOG_START -->.*?<!-- CHANGELOG_END -->/m,
          "<!-- CHANGELOG_START -->\n" + changelog + "\n<!-- CHANGELOG_END -->")
      end
      File.open("rubyforge/index.html", "w:UTF-8") do |f2|
        f2.write new_front_page
      end
    else
      puts "couldn't extract info from changelog"
    end
  end
end
gen_rubyforge.comment = "Includes the CHANGELOG into the Rubyforge front page"

Rake::TestTask.new do |t|
  t.libs << "lib"
  t.test_files = FileList['test/**/*test.rb']
  t.verbose = true
end
