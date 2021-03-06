require "spec_helper"
require "impl/evaluator_spec_base"

module LaunchDarkly
  module Impl
    describe "Evaluator (clauses)", :evaluator_spec_base => true do
      subject { Evaluator }

      it "can match built-in attribute" do
        user = { key: 'x', name: 'Bob' }
        clause = { attribute: 'name', op: 'in', values: ['Bob'] }
        flag = boolean_flag_with_clauses([clause])
        expect(basic_evaluator.evaluate(flag, user, factory).detail.value).to be true
      end

      it "can match custom attribute" do
        user = { key: 'x', name: 'Bob', custom: { legs: 4 } }
        clause = { attribute: 'legs', op: 'in', values: [4] }
        flag = boolean_flag_with_clauses([clause])
        expect(basic_evaluator.evaluate(flag, user, factory).detail.value).to be true
      end

      it "returns false for missing attribute" do
        user = { key: 'x', name: 'Bob' }
        clause = { attribute: 'legs', op: 'in', values: [4] }
        flag = boolean_flag_with_clauses([clause])
        expect(basic_evaluator.evaluate(flag, user, factory).detail.value).to be false
      end

      it "returns false for unknown operator" do
        user = { key: 'x', name: 'Bob' }
        clause = { attribute: 'name', op: 'unknown', values: [4] }
        flag = boolean_flag_with_clauses([clause])
        expect(basic_evaluator.evaluate(flag, user, factory).detail.value).to be false
      end

      it "does not stop evaluating rules after clause with unknown operator" do
        user = { key: 'x', name: 'Bob' }
        clause0 = { attribute: 'name', op: 'unknown', values: [4] }
        rule0 = { clauses: [ clause0 ], variation: 1 }
        clause1 = { attribute: 'name', op: 'in', values: ['Bob'] }
        rule1 = { clauses: [ clause1 ], variation: 1 }
        flag = boolean_flag_with_rules([rule0, rule1])
        expect(basic_evaluator.evaluate(flag, user, factory).detail.value).to be true
      end

      it "can be negated" do
        user = { key: 'x', name: 'Bob' }
        clause = { attribute: 'name', op: 'in', values: ['Bob'], negate: true }
        flag = boolean_flag_with_clauses([clause])
        expect(basic_evaluator.evaluate(flag, user, factory).detail.value).to be false
      end
    end
  end
end
