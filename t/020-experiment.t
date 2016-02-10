use v6;
use Test;
use lib 'lib';

use Test::Lab::Experiment;

class Fake is Test::Lab::Experiment {
  has $.published-result;
  has @!exceptions;
  method exceptions { @!exceptions }
  method died($operation, Exception $exception) {
    @!exceptions.push: ($operation, $exception);
  }
  method is-enabled { True }
  method publish($result) { $!published-result = $result }
  method new($name = 'experiment') { Fake.bless(:$name) }
}

subtest {
  my $ex = Test::Lab::Experiment.new('hello');
  isa-ok $ex, Test::Lab::Experiment, 'uses builtin defaults';
  is $ex.name, "hello", "default name properly set";
}, 'has a default implementation';

is Fake.new.name, "experiment", "properly defaults to 'experiment'";

subtest {
  plan 2;

  my class A is Test::Lab::Experiment {
    method new($name = 'experiment') {
      Test::Lab::Experiment.bless(:$name)
    }
  }
  my $a = A.new;

  try {
    CATCH { when X::StubCode { pass "is-enabled is a stub" }
            default { flunk "Caught the wrong error" } }
    $a.is-enabled;
    flunk "No error was thrown"
  }

  try {
    CATCH { when X::StubCode { pass "publish is a stub" }
            default { flunk "Caught the wrong error" } }
    $a.publish('result');
    flunk "No error was thrown"
  }

}, 'requires includers to implement «is-enabled» and «publish»';

subtest {
  plan 2;
  my $ex = Fake.new();
  try {
    $ex.run;
    CATCH {
      when X::BehaviorMissing {
        pass 'properly throws BehaviorMissing exception';
        is 'control', $_.name, 'the missing behavior is the control';
      }
    }
  }
}, "can't be run without a control behavior";

{
  my $ex = Fake.new();
  $ex.use: { 'control' }
  is 'control', $ex.run, 'is a straight pass-through with only a control behavior'
}

subtest {
  my $ex = Fake.new();
  $ex.use: { 'control' }
  $ex.try: { 'candidate' }

  is 'control', $ex.run;
}, 'runs other behaviors but alwas returns the control';

subtest {
  plan 3;

  my $ex = Fake.new();
  $ex.use: { 'control' }

  try {
    CATCH {
      when X::BehaviorNotUnique {
        pass 'caught duplicate control block';
        is $ex, $_.experiment, 'exception has the experiment';
        is 'control', $_.name, 'exception has the name';
      }
      default { flunk 'did not return correct Exception' }
    }
    $ex.use: { 'control-again' }
    flunk 'Did not throw error on duplicate control block';
  }

}, 'complains about duplicate behavior names';

subtest {
  my $ex = Fake.new;
  $ex.use: { 'control' }
  $ex.try: { die 'candidate' }

  is 'control', $ex.run, 'run returns value of control';
}, 'swallows exceptions thrown by candidate behaviors';

subtest {
  plan 1;

  my $ex = Fake.new;
  $ex.use: { die 'control' }
  $ex.try: { 'candidate' }

  try {
    $ex.run;
    CATCH {
      default {
        is 'control', $_.message, 'thrown message is passed to exception' }
    }
  }
}, 'passes through exceptions thrown by the control behavior';

=begin TakesLong
subtest {
  plan 1;

  my $ex = Fake.new;
  my ($last, @runs);

  $ex.use: { $last = 'control' }
  $ex.try: { $last = 'candidate' }

  for ^1000 { $ex.run; @runs.push: $last }
  ok @runs.unique.elems > 1;
}, 'shuffles behaviors before running';
=end TakesLong

subtest {
  plan 3;

  my $ex = Test::Lab::Experiment.new('hello');
  isa-ok $ex, Test::Lab::Experiment::Default;
  my role Boom { method publish($result) { die 'boomtown' } }
  $ex = $ex but Boom;

  $ex.use: { 'control' }
  $ex.try: { 'candidate' }

  try {
    $ex.run;
    CATCH {
      when X::AdHoc {
        pass 'adhoc error thrown';
        is 'boomtown', $_.message
      }
    }
    flunk 'never threw boomtown error';
  }

}, 're-throws exceptions thrown during publish by default';

subtest {
  plan 3;

  my $ex = Fake.new;
  my role Boom { method publish($result) { die 'boomtown' } }
  $ex = $ex but Boom;

  $ex.use: { 'control' }
  $ex.try: { 'candidate' }

  is 'control', $ex.run;

  my (\op, \exception) = $ex.exceptions.pop;

  is 'publish', op;
  is 'boomtown', exception.message;
}, 'reports publishing errors';

subtest {
  plan 2;

  my $ex = Fake.new;
  $ex.use: { 1 }
  $ex.try: { 1 }

  is 1, $ex.run;
  ok $ex.published-result.defined;
}, 'publishes results';

subtest {
  plan 2;

  my $ex = Fake.new;
  $ex.use: { 1 }

  is 1, $ex.run;
  nok $ex.published-result;
}, 'does not publish results when there is only a control value';

subtest {
  plan 2;

  my $ex = Fake.new;
  $ex.comparator = -> $a, $b { $a ~~ $b }
  $ex.use: { '1' }
  $ex.try: {  1  }

  is '1', $ex.run;
  say $ex.published-result.is-matched;
  ok $ex.published-result.is-matched;
}, 'compares results with a comparator block if provided';

subtest {
  plan 2;

  my $experiment = Fake.new;
  my Test::Lab::Observation $a .= new(:name('a'), :$experiment, :block({ 1 }));
  my Test::Lab::Observation $b .= new(:name('b'), :$experiment, :block({ 2 }));

  ok  $experiment.obs-are-equiv($a, $a);
  nok $experiment.obs-are-equiv($a, $b);
}, 'uses a compare block to detminer if observatiosn are equivalent';

done-testing;
