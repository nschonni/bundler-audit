require 'spec_helper'

describe "CLI" do
  include Helpers

  let(:bundler_audit) do
    File.expand_path(File.join(File.dirname(__FILE__),'..','bin','bundler-audit'))
  end
  let(:command) do
    "#{bundler_audit} check -D #{Fixtures::Database::PATH}"
  end

  context "when auditing a bundle with unpatched gems" do
    let(:bundle)    { 'unpatched_gems' }
    let(:directory) { File.join('spec','bundle',bundle) }

    subject do
      Dir.chdir(directory) { sh(command, :fail => true) }
    end

    it "should print a warning" do
      expect(subject).to include("Vulnerabilities found!")
    end

    it "should print advisory information for the vulnerable gems" do
      advisory_pattern = %r{(Name: [^\n]+
Version: \d+\.\d+\.\d+(\.\d+)?
CVE: CVE-[0-9]{4}-[0-9]{4}
Criticality: (Critical|High|Medium|Low|None|Unknown)
URL: https?://(www\.)?[-a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,6}\b([-a-zA-Z0-9@:%_\+.~#!?&//=]*)
Title: [^\n]*?
Solution: upgrade to (~>|>=) \d+\.\d+\.\d+(\.\d+)?(, (~>|>=) \d+\.\d+\.\d+(\.\d+)?)*[\s\n]*?)}

      expect(subject).to match(advisory_pattern)
      expect(subject).to include("Vulnerabilities found!")
    end
  end

  context "when auditing a bundle with ignored gems" do
    let(:bundle)    { 'unpatched_gems' }
    let(:directory) { File.join('spec','bundle',bundle) }
    let(:command)   { "#{super()} -i CVE-2013-0156" }

    subject do
      Dir.chdir(directory) { sh(command, :fail => true) }
    end

    it "should not print advisory information for ignored gem" do
      expect(subject).not_to include("CVE-2013-0156")
    end
  end

  context "when auditing a bundle with insecure sources" do
    let(:bundle)    { 'insecure_sources' }
    let(:directory) { File.join('spec','bundle',bundle) }

    subject do
      Dir.chdir(directory) { sh(command, :fail => true) }
    end

    it "should print warnings about insecure sources" do
      expect(subject).to include(%{
Insecure Source URI found: git://github.com/rails/jquery-rails.git
Insecure Source URI found: http://rubygems.org/
      }.strip)
    end
  end

  context "when auditing a secure bundle" do
    let(:bundle)    { 'secure' }
    let(:directory) { File.join('spec','bundle',bundle) }

    subject do
      Dir.chdir(directory) { sh(command) }
    end

    it "should print nothing when everything is fine" do
      expect(subject.strip).to eq("No vulnerabilities found")
    end
  end

  context "when auditing a non-existent Gemfile.lock file" do
    let(:bundle)    { 'secure' }
    let(:directory) { File.join('spec','bundle',bundle) }
    let(:root)      { File.expand_path(directory) }

    let(:gemfile_lock) { 'Gemfile.foo.lock' }
    let(:command)      { "#{super()} --gemfile-lock #{gemfile_lock}" }

    subject do
      Dir.chdir(directory) { sh(command, :fail => true) }
    end

    it "should print an error message" do
      expect(subject.strip).to eq("Could not find #{gemfile_lock.inspect} in #{root.inspect}")
    end
  end

  describe "update" do
    let(:command)   { "#{bundler_audit} update" }
    let(:bundle)    { 'secure' }
    let(:directory) { File.join('spec','bundle',bundle) }

    subject do
      Dir.chdir(directory) { sh(command) }
    end

    context "when advisories update successfully" do
      it "should print status" do
        expect(subject).not_to include("Fail")
        expect(subject).to include("Updating ruby-advisory-db ...\n")
        expect(subject).to include("Updated ruby-advisory-db\n")
        expect(subject).to match(/ruby-advisory-db:\n  advisories:\s+[1-9]\d+ advisories/)
      end
    end
  end
end
