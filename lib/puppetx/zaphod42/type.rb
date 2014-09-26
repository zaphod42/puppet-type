require 'puppetx'
require 'puppet/pops'

module Puppetx::Zaphod42
  module Type
    require 'puppetx/zaphod42/type/inferer'

    def self.infer_string(code_string)
      parser = Puppet::Pops::Parser::Parser.new()
      type_inferer = Puppetx::Zaphod42::Type::Inferer.new

      ast = parser.parse_string(code_string)
      type_inferer.infer(ast.model)
    end
  end
end
