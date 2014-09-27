# Type Inference

#### Table of Contents

1. [Overview](#overview)
2. [Module Description - What the module does and why it is useful](#module-description)
4. [Usage - Configuration options and additional functionality](#usage)
5. [Limitations - OS compatibility, etc.](#limitations)
6. [Development - Guide for contributing to the module](#development)

## Overview

Statically check your puppet code for type errors!

## Module Description

Type inference is a technique that extracts the type information from
expressions in a programming language. This means that the benefits of static
typing can be had without having to explicity give the types everywhere.

This module provides a type inference system and several new subcommands so
that you can type check your code.

This requires puppet 3.7 or greater.

## Usage

```
> puppet type infer '1'
Integer[1, 1]
```

```
> puppet type infer '{ a => 1 }'
Hash[String, Integer[1, 1]]
```

## Limitations

Lots. This is still very early stages.

## Development

1. Fork
2. Hack + Test
3. Send a PR

Understanding the [puppet language
specification](https://github.com/puppetlabs/puppet-specifications) will really
be needed.
