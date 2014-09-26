require 'spec_helper'
require 'puppetx/zaphod42/type'

describe 'Type Inference' do
  {
    "undef" => "Undef",

    "1" => "Integer[1, 1]",
    "1.0" => "Float[1.0, 1.0]",
    "0xf" => "Integer[15, 15]",

    "'string'" => "String",
    "string" => "String",
    "\"string\"" => "String",

    "$a =~ /re/" => "Boolean",

    "$a and $b" => "Boolean",
    "$a or $b" => "Boolean",

    "1 + 1" => "Integer",
    "1 * 1" => "Integer",
    "1 / 1" => "Integer",
    "1 / 2.0" => "Float",
    "1 + 1.0" => "Float",
    "1.0 + 1" => "Float",

    "{}" => "Hash",
    "{ 1 => 1 }" => "Hash[Integer[1, 1], Integer[1, 1]]",
    "{ 1 => 1, 2 => 2 }" => "Hash[Integer[1, 2], Integer[1, 2]]",
    "{ 1 => 1, 2.0 => 2.0 }" => "Hash[Variant[Integer[1, 1], Float[2.0, 2.0]], Variant[Integer[1, 1], Float[2.0, 2.0]]]",
    "{ 1 => 1, a => {} }" => "Hash[Variant[Integer[1, 1], String], Variant[Integer[1, 1], Hash]]",

    "[]" => "Array[Data, 0, 0]",
    "[1]" => "Array[Integer[1, 1], 1, 1]",

    "$var = 1" => "Integer[1, 1]",
    "if $b { 1 } else { 2 }" => "Integer[1, 2]",
    "if $b { 1 }" => "Variant[Integer[1, 1], Undef]",

    "1; 'string'" => "String",
    "$var = 1; $var" => "Integer[1, 1]",
    "$h = { a => 1 }; $h[$x]" => "Optional[Integer[1, 1]]",
    "$h = { a => { b => 2.0 } }; $h[$x][$y]" => "Optional[Float[2.0, 2.0]]",

    "$a = [1]; $a[$x]" => "Optional[Integer[1, 1]]",
    "$a = [[1]]; $a[$x][$y]" => "Optional[Integer[1, 1]]",

    "notify { hi: }" => "Resource[Notify]",

    "define a(String $x) {}" => "Undef",
  }.each do |example, expectation|
    it "infers <#{example}> to have type #{expectation}" do
      expect(example).to infer_type(expectation)
    end
  end

  {
    "define a(String $x) {} a { hi: x => 1 }" => /expected String got Integer/,
    "class a(String $x) {} class { a: x => 1 }" => /expected String got Integer/,

    "define a(String $x) {} $y = 1; a { hi: x => $y }" => /expected String got Integer/
  }.each do |example, expectation|
    it "infers that <#{example}> contains a type error of <#{expectation}>" do
      expect do
        Puppetx::Zaphod42::Type.infer_string(example)
      end.to raise_error(expectation)
    end
  end

  RSpec::Matchers.define :infer_type do |expected|
    match do |actual|
      type_parser = Puppet::Pops::Types::TypeParser.new

      @inferred_type = Puppetx::Zaphod42::Type.infer_string(actual)
      @inferred_type == type_parser.parse(expected)
    end

    failure_message do |actual|
      "expected to infer <#{actual}> to have type #{expected}, but got #{@inferred_type}"

    end
  end
end
