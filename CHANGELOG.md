# Changelog

## Currently in development (at least >= 1.1 because of API changes)


### Features

- Monomorphize the parser module to `… -> StgParser a` for readability (was
  `(TokenParsing parser, Monad parser) => … -> StgParser a`)

### Fixes

- Fixed a bug that made case evaluation/return frames unnecessarily prolong the
  lifetime of objects (#86)

### Refactoring

- Split evaluation into valid and error rule modules
- Give rules more detailed names, e.g. `rule1_functionApp`

### Documentation

- Document each rule individually with Haddock
- Add lots of docstrings



## 1.0.1


### Functionality

- Add `partition` to Prelude
- Implement `naiveSort` in terms of `partition`

### Documentation

- Small fixes



## 1

(Initial release)
