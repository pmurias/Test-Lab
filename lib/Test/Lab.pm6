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
sub lab (Str:D $name, &procedure, :$run) is export {
  my $experiment = $experiment-class.new(:$name);

  &procedure($experiment);

  $experiment.run($run // 'control');
}
