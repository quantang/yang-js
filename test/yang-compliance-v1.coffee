describe "YANG 1.0 (RFC-6020) Compliance:", ->
  global.yang = require '..'

  describe 'leaf',      -> require './extensions/leaf'
  describe 'leaf-list', -> require './extensions/leaf-list'
  describe 'container', -> require './extensions/container'
  describe 'list',      -> require './extensions/list'
  describe 'type',      -> require './extensions/type'
  describe 'rpc',       -> require './extensions/rpc'
  describe 'grouping',  -> require './extensions/grouping'
  describe 'module',    -> require './extensions/module'
  describe 'import',    -> require './extensions/import'
