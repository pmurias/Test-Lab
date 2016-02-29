unit module Test::Lab;

use Test::Lab::Experiment;

#| Change the default Experiment class to instantiate by modifying
#| this variable.
our $experiment-class = Test::Lab::Experiment;

#| Define and run a lab experiment
#|
#| $name - name for this experiment
#| &procedure - routine that takes an experiment & lays out groups and context.
#| $run - name of the test to run
#|
#| Returns the calculated value of the given $run experiment, or raises
#| if an exception was raised.

sub lab($name, :$use, :$try, :$run='control', :%context) is export {
  my $experiment = $experiment-class.new(:$name, :%context);
  
  $experiment.use($use) if defined $use;
  if $try ~~ Associative {
    for $try.kv -> $name, $code {
      $experiment.try($code, :$name);
    }
  } else {
    $experiment.try($try) if defined $try;
  }

  $experiment.run($run);
}
