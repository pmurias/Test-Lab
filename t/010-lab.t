use v6;
use Test;
use lib 'lib';

use Test::Lab;

use-ok 'Test::Lab';

{
  my $r = lab 'test',
    use => { 'control' },
    try => { 'candidate' }

  is $r, 'control', 'provides a helper to instantiate and run experiments';
}

{
  my $result = lab 'test',
    :run<first-way>,
    try => {
        first-way  => { True  },
        second-way => { False }
    }

  ok $result, 'Runs the named test instead of the control';
}

{
  my $experiment;

  my $result = lab 'test',
    :run(Nil),
    use => { True },
    try => {
        second-way => { False }
    }

  ok $result, 'Runs control when there is a Nil named test';
}

{
  my $control-result;
  my $context;

  class NewDefault is Test::Lab::Experiment {
    method is-enabled { True }
    method publish($result) {
        $control-result := $result.control.value;
        $context := $result.context;
    }
  }

  Test::Lab::<$experiment-class> = NewDefault;

  lab 'test',
    use => { "correct experimental result" },
    try => { "incorrect experimental result" },
    context => { foo => "bar", "baz" => "foo" }


  is $control-result, "correct experimental result", 'setting $experimental-class works';
  is $context, {foo => "bar", "baz" => "foo"}, 'context to lab';
}

done-testing;
