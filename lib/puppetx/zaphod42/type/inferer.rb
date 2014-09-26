class Puppetx::Zaphod42::Type::Inferer
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
    @type_factory.undef
  end

  def infer_LiteralInteger(ast)
    int = @type_factory.integer
    int.from = int.to = ast.value
    int
  end

  def infer_LiteralFloat(ast)
    float = @type_factory.float
    float.from = float.to = ast.value
    float
  end

  def infer_LiteralString(ast)
    @type_factory.string
  end

  def infer_QualifiedName(ast)
    @type_factory.string
  end

  def infer_LiteralHash(ast)
    entry_types = ast.entries.collect do |entry|
      [infer(entry.key), infer(entry.value)]
    end

    if entry_types.empty?
      @type_factory.hash_of_data
    else
      @type_factory.hash_of(union_type(entry_types.collect(&:last)),
                            union_type(entry_types.collect(&:first)))
    end
  end

  def infer_LiteralList(ast)
    value_types = ast.values.collect(&method(:infer))

    array = if value_types.empty?
              @type_factory.array_of(@type_factory.data)
            else
              @type_factory.array_of(union_type(value_types))
            end
    array.size_type = @type_factory.integer
    array.size_type.from = array.size_type.to = value_types.length
    array
  end

  def infer_ArithmeticExpression(ast)
    left = infer(ast.left_expr)
    right = infer(ast.right_expr)

    if left.class == Puppet::Pops::Types::PFloatType || right.class == Puppet::Pops::Types::PFloatType
      @type_factory.float
    else
      @type_factory.integer
    end
  end

  def infer_AssignmentExpression(ast)
    type = infer(ast.right_expr)
    @variables[ast.left_expr.expr.value] = type
    type
  end

  def infer_IfExpression(ast)
    covering_type(infer(ast.then_expr), infer(ast.else_expr))
  end

  def infer_VariableExpression(ast)
    name = ast.expr.value
    if @variables.include?(name)
      @variables[name]
    else
      @type_factory.undef
    end
  end

  def infer_MatchExpression(ast)
    infer(ast.left_expr) # assert String
    infer(ast.right_expr) # assert Pattern
    @type_factory.boolean
  end

  def infer_OrExpression(ast)
    infer(ast.left_expr) # assert?
    infer(ast.right_expr) # assert?
    @type_factory.boolean
  end

  def infer_AndExpression(ast)
    infer(ast.left_expr) # assert?
    infer(ast.right_expr) # assert?
    @type_factory.boolean
  end

  def infer_LiteralRegularExpression(ast)
    @type_factory.regexp
  end

  def infer_AccessExpression(ast)
    left = infer(ast.left_expr)
    unpacked = if left.is_a?(Puppet::Pops::Types::POptionalType)
                 # WARNING!!!! Possible undef dereference
                 left.optional_type.element_type
               else
                 left.element_type
               end
    @type_factory.optional(unpacked)
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
          inferred_type = infer(operation.value_expr)
          if !@type_calculator.assignable?(declared_type, inferred_type)
            raise "Error in ResourceExpression for parameter #{operation.attribute_name}: expected #{declared_type} got #{inferred_type}"
          end
        end
      end
    end
    @type_factory.resource(name)
  end

  def infer_ResourceTypeDefinition(ast)
    evaluator = Puppet::Pops::Evaluator::EvaluatorImpl.new()
    @defines[ast.name] = Hash[ast.parameters.collect do |param|
      [param.name, evaluator.evaluate(param.type_expr, nil)]
    end]

    @type_factory.undef
  end

  def infer_HostClassDefinition(ast)
    evaluator = Puppet::Pops::Evaluator::EvaluatorImpl.new()
    @classes[ast.name] = Hash[ast.parameters.collect do |param|
      [param.name, evaluator.evaluate(param.type_expr, nil)]
    end]

    @type_factory.undef
  end

  def infer_Nop(ast)
    @type_factory.undef
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
