class Puppetx::Zaphod42::Type::Inferer
  class Context
    attr_reader :type

    def initialize(type)
      @type = type
    end
  end

  def initialize
    @infer_visitor = Puppet::Pops::Visitor.new(self, "infer", 0, 0)
    @type_factory = Puppet::Pops::Types::TypeFactory
    @type_calculator = Puppet::Pops::Types::TypeCalculator.new
    @variables = {}
    @defines = {}
    @classes = {}
  end

  def infer(ast)
    @infer_visitor.visit(ast)
  end

  def infer_Program(ast)
    @infer_visitor.visit(ast.body)
  end

  def infer_BlockExpression(ast)
    ast.statements.collect do |statement|
      infer(statement)
    end.last
  end

  def infer_LiteralUndef(ast)
    Context.new(@type_factory.undef)
  end

  def infer_LiteralInteger(ast)
    int = @type_factory.integer
    int.from = int.to = ast.value
    Context.new(int)
  end

  def infer_LiteralFloat(ast)
    float = @type_factory.float
    float.from = float.to = ast.value
    Context.new(float)
  end

  def infer_LiteralRegularExpression(ast)
    Context.new(@type_factory.regexp(ast.pattern))
  end

  def infer_LiteralString(ast)
    Context.new(@type_factory.string)
  end

  def infer_QualifiedName(ast)
    Context.new(@type_factory.string)
  end

  def infer_LiteralHash(ast)
    entry_types = ast.entries.collect do |entry|
      [infer(entry.key), infer(entry.value)]
    end

    Context.new(if entry_types.empty?
      @type_factory.hash_of_data
    else
      @type_factory.hash_of(union_type(entry_types.collect(&:last).collect(&:type)),
                            union_type(entry_types.collect(&:first).collect(&:type)))
    end)
  end

  def infer_LiteralList(ast)
    value_types = ast.values.collect(&method(:infer))

    array = if value_types.empty?
              @type_factory.array_of(@type_factory.data)
            else
              @type_factory.array_of(union_type(value_types.collect(&:type)))
            end
    array.size_type = @type_factory.integer
    array.size_type.from = array.size_type.to = value_types.length
    Context.new(array)
  end

  def infer_ConcatenatedString(ast)
    ast.segments.each do |segment|
      infer(segment)
    end

    Context.new(@type_factory.string)
  end

  def infer_UnaryExpression(ast)
    infer(ast.expr)
  end

  def infer_ArithmeticExpression(ast)
    left = infer(ast.left_expr)
    right = infer(ast.right_expr)

    Context.new(case left.type
    when Puppet::Pops::Types::PIntegerType
      if right.type.is_a?(Puppet::Pops::Types::PFloatType)
        @type_factory.float
      else
        @type_factory.integer
      end
    when Puppet::Pops::Types::PFloatType
      @type_factory.float
    when Puppet::Pops::Types::PHashType
      @type_factory.hash_of_data
    when Puppet::Pops::Types::PArrayType
      @type_factory.array_of_data
    else
      @type_factory.variant(
        @type_factory.hash_of_data,
        @type_factory.array_of_data,
        @type_factory.float,
        @type_factory.integer)
    end)
  end

  def infer_AssignmentExpression(ast)
    type = infer(ast.right_expr).type
    @variables[ast.left_expr.expr.value] = type
    Context.new(type)
  end

  def infer_IfExpression(ast)
    Context.new(covering_type(infer(ast.then_expr).type, infer(ast.else_expr).type))
  end

  def infer_VariableExpression(ast)
    name = ast.expr.value
    Context.new(if @variables.include?(name)
      @variables[name]
    else
      @type_factory.undef
    end)
  end

  def infer_MatchExpression(ast)
    infer(ast.left_expr) # assert String
    infer(ast.right_expr) # assert Pattern
    Context.new(@type_factory.boolean)
  end

  def infer_OrExpression(ast)
    infer(ast.left_expr) # assert?
    infer(ast.right_expr) # assert?
    Context.new(@type_factory.boolean)
  end

  def infer_AndExpression(ast)
    infer(ast.left_expr) # assert?
    infer(ast.right_expr) # assert?
    Context.new(@type_factory.boolean)
  end

  def infer_NotExpression(ast)
    infer(ast.expr)
    Context.new(@type_factory.boolean)
  end

  def infer_AccessExpression(ast)
    left = infer(ast.left_expr).type
    unpacked = if left.is_a?(Puppet::Pops::Types::POptionalType)
                 # WARNING!!!! Possible undef dereference
                 left.optional_type.element_type
               else
                 left.element_type
               end
    Context.new(@type_factory.optional(unpacked))
  end

  def infer_ResourceExpression(ast)
    name = ast.type_name.value
    if @defines.include?(name) || name == "class"
      ast.bodies.each do |body|
        type = if name == "class"
                  @classes[body.title.value]
                else
                  @defines[name]
                end
        body.operations.each do |operation|
          declared_type = type[operation.attribute_name]
          inferred = infer(operation.value_expr)
          if !@type_calculator.assignable?(declared_type, inferred.type)
            raise "Error in ResourceExpression for parameter #{operation.attribute_name}: expected #{declared_type} got #{inferred.type}"
          end
        end
      end
    end
    Context.new(@type_factory.resource(name))
  end

  def infer_ResourceTypeDefinition(ast)
    evaluator = Puppet::Pops::Evaluator::EvaluatorImpl.new()
    @defines[ast.name] = Hash[ast.parameters.collect do |param|
      [param.name, evaluator.evaluate(param.type_expr, nil)]
    end]

    Context.new(@type_factory.undef)
  end

  def infer_HostClassDefinition(ast)
    evaluator = Puppet::Pops::Evaluator::EvaluatorImpl.new()
    @classes[ast.name] = Hash[ast.parameters.collect do |param|
      [param.name, evaluator.evaluate(param.type_expr, nil)]
    end]

    Context.new(@type_factory.undef)
  end

  def infer_Nop(ast)
    Context.new(@type_factory.undef)
  end

  # Given a set of types return the most restrictive type that will allow all
  # of the given types.
  def union_type(types)
    types.inject do |a, b|
      covering_type(a, b)
    end
  end

  # Return the most restrictive type that allows both given types
  def covering_type(a, b)
    if @type_calculator.assignable?(a, b)
      a
    elsif @type_calculator.assignable?(b, a)
      b
    elsif a.class == b.class
      @type_calculator.common_type(a, b)
    else
      @type_factory.variant(a, b)
    end
  end
end
