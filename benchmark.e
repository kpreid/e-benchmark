#!/usr/bin/env rune -cpa lib/

# Copyright 2006-2008 Kevin Reid, under the terms of the MIT X license
# found at http://www.opensource.org/licenses/mit-license.html ................

pragma.syntax("0.9")
pragma.enable("accumulator")

# XXX don't require classpath changes
def benchmarks := <import:benchmarks.benchmarks>

/** Do-nothing benchmark, used to remove constant overhead from measurement. */
def empty() {}

def measureN(routine, times) {
  var i := 0
  def before := timer.now()
  while ((i += 1) <= times) {
    routine()
  }
  def after := timer.now()
  return after - before
}

def milliToMicro := 1000

/** Compute the average resource use of a function; returns a time in microseconds and the number of iterations used per timing segment. */
def measure(routine) {
  routine() # discard first run to ignore cache effects
  
  var timeSpent := 0
  var iterationsDone := 0
  while (timeSpent < 2000) { # 2 seconds
    def step := 4.max(iterationsDone)
    timeSpent += measureN(routine, step)
    iterationsDone += step
  }
  
  return [timeSpent * milliToMicro // (iterationsDone), iterationsDone]
}

def lJustify(s, n) { return (s + " " * n).run(0, n.max(s.size())) }
def rJustify(s, n) { return (" " * n.max(s.size()) + s).run(s.size()) }

def runBenchmarks(out, table) {
  measure(empty)
  #def emptyTime := measure(empty)
  #out.println("Empty: " + emptyTime)
  for name => routine in table {
    out.print(lJustify(name, 20), " ")

    try { routine() } catch p {
      def i := out.indent(" " * 21)
      i.print("Failed: ")
      i.quote(p)
      out.println()
      continue
    }

    def [tRun, iRun] := measure(routine)
    def [tNull, iNull] := measure(empty)
    out.print(rJustify(E.toString(tRun - tNull), 8), " us ")
    out.print(`[$iRun $iNull]`)
    out.println()
  }
}


# ------------------------------------------------------------------------------

switch (interp.getArgs()) {
  match [s] { runBenchmarks(stdout, accum [].asMap() for k ? (k =~ `@{_}$s@{_}`) => v in benchmarks {_.with(k, v)}) }
  match [] { runBenchmarks(stdout, benchmarks) }
}
