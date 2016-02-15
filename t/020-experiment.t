use v6;
use Test;
use lib 'lib';

use Test::Lab::Experiment;
use Test::Lab::Result;

class Fake is Test::Lab::Experiment {
  has $.published-result;
  has @!exceptions;
  method exceptions { @!exceptions }
  method died($operation, Exception $exception) {
    @!exceptions.push: ($operation, $exception);
  }
  method is-enabled { True }
  method publish(Test::Lab::Result $result) { $!published-result = $result }
  method new($name = 'experiment') { Fake.bless(:$name) }
}

subtest {
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

  {
    my $ex = Fake.new();
    $ex.use: { 'control' }
    $ex.try: { 'candidate' }

    is 'control', $ex.run, 'runs other behaviors but alwas returns the control';
  }

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

  {
    my $ex = Fake.new;
    $ex.use: { 'control' }
    $ex.try: { die 'candidate' }

    is 'control', $ex.run, 'swallows exceptions thrown by candidate behaviors';
  }

  {
    my $ex = Fake.new;
    $ex.use: { die 'control' }
    $ex.try: { 'candidate' }

    try {
      $ex.run;
      CATCH {
        default {
          is 'control', $_.message,
             'passes through exceptions thrown by the control behavior' }
      }
    }
  }

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

    my Fake $ex .= new;
    $ex.comparator = -> $a, $b { $a ~~ $b }
    $ex.use: { '1' }
    $ex.try: {  1  }

    is '1', $ex.run;
    ok $ex.published-result.is-matched;
  }, 'compares results with a comparator block if provided';

  subtest {
    plan 2;

    my Fake $experiment .= new;
    my Test::Lab::Observation $a .= new :name('a') :$experiment :block({ 1 });
    my Test::Lab::Observation $b .= new :name('b') :$experiment :block({ 2 });

    ok  $experiment.obs-are-equiv($a, $a);
    nok $experiment.obs-are-equiv($a, $b);
  }, 'knows how to compare two experiments';

  {
    my Fake $experiment .= new;
    my Test::Lab::Observation $a .= new :name('a') :$experiment :block({ '1' });
    my Test::Lab::Observation $b .= new :name('b') :$experiment :block({  1  });
    $experiment.comparator = -> $a, $b { $a ~~ $b };

    ok $experiment.obs-are-equiv($a, $b),
      'uses a compare block to determine if observations are equivalent';
  }

  subtest {
    plan 3;

    my Fake $experiment .= new;
    $experiment.comparator = -> $a, $b { die 'boomtown' }
    $experiment.use: { 'control' }
    $experiment.try: { 'candidate' }

    is 'control', $experiment.run;

    my (\op, \ex) = $experiment.exceptions.pop;

    is 'compare', op;
    is 'boomtown', ex.message;
  }, 'reports errors in a compare block';

  subtest {
    plan 3;

    my Fake $experiment .= new;
    my role EnabledError { method is-enabled { die 'kaboom' } };
    $experiment = $experiment but EnabledError;
    $experiment.use: { 'control' }
    $experiment.try: { 'candidate' }

    is 'control', $experiment.run;

    my (\op, \ex) = $experiment.exceptions.pop;

    is 'enabled', op;
    is 'kaboom', ex.message;
  }, 'reports errors in the is-enabled method';

  subtest {
    plan 3;

    my Fake $experiment .= new;
    $experiment.run-if = { die 'kaboom' }
    $experiment.use: { 'control' }
    $experiment.try: { 'candidate' }

    is 'control', $experiment.run;

    my (\op, \ex) = $experiment.exceptions.pop;

    is 'run-if', op;
    is 'kaboom', ex.message;
  }, 'reports errors in a run-if block';

  {
    my Fake $experiment .= new;

    is $experiment.clean-value(10), 10, 'returns the given value when no clean block is configured';
  }

  {
    my Fake $experiment .= new;
    $experiment.cleaner = { .uc }

    is $experiment.clean-value('test'), 'TEST',
      'calls the configured clean routine with a value when configured';
  }

  subtest {
    plan 4;

    my Fake $experiment .= new;
    $experiment.cleaner = -> $value { die 'kaboom' }
    $experiment.use: { 'control' }
    $experiment.try: { 'candidate' }

    is $experiment.run, 'control';
    is $experiment.published-result.control.cleaned-value, 'control';

    my (\op, \ex) = $experiment.exceptions.pop;

    is op, 'clean';
    is ex.message, 'kaboom';
  }, 'reports an error and returns the original vlaue when an' ~
     'error is raised in a clean block';

}, 'Test::Lab::Experiment';

subtest {
  {
    my ($candidate-ran, $run-check-ran) = False xx 2;
    my Fake $experiment .= new;
    $experiment.use: { 1 }
    $experiment.try: { $candidate-ran = True; 1 }
    $experiment.run-if = { $run-check-ran = True; False }

    $experiment.run;

    ok  $run-check-ran, 'run-if is properly called';
    nok $candidate-ran, 'does not run the experiment if run-if returns false';
  }

  {
    my ($candidate-ran, $run-check-ran) = False xx 2;
    my Fake $experiment .= new;
    $experiment.use: { True }
    $experiment.try: { $candidate-ran = True }
    $experiment.run-if = { $run-check-ran = True }

    $experiment.run;

    ok $run-check-ran, 'run-if is properly called';
    ok $candidate-ran, 'runs the experiment if the given block returns true';
  }
}, 'Test::Lab::Experiment.run-if';

subtest {
  sub prep {
    my Fake $experiment .= new;
    ($experiment,
     Test::Lab::Observation.new :name<a> :$experiment :block({ 1 }),
     Test::Lab::Observation.new :name<b> :$experiment :block({ 2 }))
  }
  sub it($behavior, &block) {
    my ($*ex, $*a, $*b) = prep();
    subtest &block, $behavior;
  }

  it 'does not ignore an observation if no ignores are configured', {
    nok $*ex.ignore-mismatched-obs($*a, $*b);
  }

  it 'calls a configured ignore block with the given observed values', {
    my $c = False;
    $*ex.ignore: -> $a, $b {
      $c = True; is $*a.value, $a; is $*b.value, $b; True
    }
    ok $*ex.ignore-mismatched-obs($*a, $*b);
    ok $c;
  }

  it 'calls multiple ignore blocks to see if any match', {
    my ($called-one, $called-two, $called-three) = False xx 3;
    $*ex.ignore: -> $a, $b { $called-one   = True; False }
    $*ex.ignore: -> $a, $b { $called-two   = True; False }
    $*ex.ignore: -> $a, $b { $called-three = True; False }
    nok $*ex.ignore-mismatched-obs($*a, $*b);
    ok $called-one;
    ok $called-two;
    ok $called-three;
  }

  it "only calls ignore blocks until one matches", {
    my ($called-one, $called-two, $called-three) = False xx 3;
    $*ex.ignore: -> $a, $b { $called-one   = True; False }
    $*ex.ignore: -> $a, $b { $called-two   = True; True  }
    $*ex.ignore: -> $a, $b { $called-three = True; False }
    ok $*ex.ignore-mismatched-obs: $*a, $*b;
    ok $called-one;
    ok $called-two;
    nok $called-three;
  }

  it 'reports exceptions raised in an ignore block and returns false', {
    $*ex.ignore: -> $a, $b { die 'kaboom' }
    nok $*ex.ignore-mismatched-obs($*a, $*b);
    my (\op, \exception) = $*ex.exceptions.pop;
    is op, 'ignore';
    is exception.message, 'kaboom';
  }

  it 'skips ignore blocks that throw and tests any remaining' ~
     'blocks if an exception is swalloed', {
    $*ex.ignore: { die 'kaboom' }
    $*ex.ignore: { True }
    ok $*ex.ignore-mismatched-obs($*a, $*b);
    is $*ex.exceptions.elems, 1;
  }

}, 'Test::Lab::Experiment.ignore-mismatched-obs';



done-testing;
