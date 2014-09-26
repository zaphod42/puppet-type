require 'puppet/face'
require 'puppetx/zaphod42/type'

Puppet::Face.define(:type, '0.1.0') do
  copyright "Andrew Parker", 2014
  license   "Apache 2"

  summary "Type check puppet manifests"

  action(:infer) do
    summary "Infer the type of a puppet language expression"
    arguments "<source>"

    description <<-'EOT'
    EOT

    examples <<-'EOT'
    EOT

    when_invoked do |code, options|
      Puppetx::Zaphod42::Type.infer_string(code)
    end

    when_rendering(:console) do |type|
      type.to_s
    end
  end
end
