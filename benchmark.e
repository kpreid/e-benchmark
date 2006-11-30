#!/usr/bin/env rune

# Copyright 2006 Kevin Reid, under the terms of the MIT X license
# found at http://www.opensource.org/licenses/mit-license.html ................

pragma.enable("easy-return")
pragma.disable("explicit-result-guard")

pragma.enable("anon-lambda")
pragma.enable("accumulator")

def range(a, b) {
  return def cheapRange {
    to iterate(f) {
      var i := a
      while (i < b) {
        f(i, i)
        i += 1
      }
    }
  } 
}

# ------------------------------------------------------------------------------

/** Do-nothing benchmark, used to remove constant overhead from measurement. */
def empty() {}

def callHost() {
  # XXX this is subject to constant folding
  1234 + 5678
}

def callE() {
  # XXX this is subject to constant folding
  thunk { 1 } ()
}

#def doSomeStuff() {
#  e`def x := 0; def y := 1`.eval(safeScope)
#}

def makeAndCallMapSugar() {
  def m1 := [1 => 2, 3 => 4]
  def m2 := [5 => 6, 7 => 8]
  return m1 | m2
}

def makeAndCallMapSimple() {
  def m1 := [1 => 2, 3 => 4]
  return m1.fetch(1, fn {0})
}

def testList10 := { def l := [].diverge(); for i in range(0, 10) { l.push(i) }; l.snapshot() }
def testList100 := { def l := [].diverge(); for i in range(0, 100) { l.push(i) }; l.snapshot() }
def testList1000 := { def l := [].diverge(); for i in range(1, 1000) { l.push(i) }; l.snapshot() }

# Things which are defaulted/able (sugar) operations on lists in E-on-CL at the moment

def listRun1(l) { return fn {
  l.run(l.size() // 3)
}}

def listRun2(l) { return fn {
  l.run(l.size() // 3, l.size() // 1.5)
}}

def listDiverge(l) { return fn {
  l.diverge()
}}
def listDivergeFloat(l) { return fn {
  l.diverge(float64)
}}
def anyish { to coerce(specimen, optEjector) { return specimen }}
def listDivergeAnyish(l) { return fn {
  l.diverge(anyish)
}}

def listIterate(l) { return fn {
  var sum := 0
  l.iterate(fn k, v {sum += v})
  sum
}}

# ------------------------------------------------------------------------------

def benchmarks := [
  => callHost, => callE,
  => makeAndCallMapSimple, => makeAndCallMapSugar,
  "listRun1 10" => listRun1(testList10),
  "listRun1 100" => listRun1(testList100),
  "listRun1 1000" => listRun1(testList1000),
  "listRun2 10" => listRun2(testList10),
  "listRun2 100" => listRun2(testList100),
  "listRun2 1000" => listRun2(testList1000),
  "listIterate 10" => listIterate(testList10),
  "listIterate 100" => listIterate(testList100),
  "listIterate 1000" => listIterate(testList1000),
  "listDiverge 10" => listDiverge(testList10),
  "listDiverge 100" => listDiverge(testList100),
  "listDiverge 1000" => listDiverge(testList1000),
  "listDivergeAnyish 10" => listDivergeAnyish(testList10),
  "listDivergeAnyish 100" => listDivergeAnyish(testList100),
  "listDivergeAnyish 1000" => listDivergeAnyish(testList1000),
  "listDivergeFloat 10" => listDivergeFloat(testList10),
  "listDivergeFloat 100" => listDivergeFloat(testList100),
  "listDivergeFloat 1000" => listDivergeFloat(testList1000),
]

# ------------------------------------------------------------------------------


#def timesIn := 20000
def timesOut := 3

def measureN(routine, times) {
  var i := 0
  def before := timer.now()
  while ((i += 1) <= times) {
    routine()
  }
  def after := timer.now()
  return after - before
}

/** Compute the average resource use of a function; returns a time in microseconds and the number of iterations used per timing segment. */
def measure(routine) {
  routine() # discard first run to ignore cache effects
  
  # figure appropriate number of iterations
  var timesIn := 1
  var timeSpent := 0
  while (timeSpent < 2000) { # 2 seconds
    timesIn *= 2
    timeSpent := measureN(routine, timesIn)
  }
  
  var sum := 0
  for _ in range(0, timesOut) {
    sum += measureN(routine, timesIn)
  }
  return [sum * 1000 // (timesIn * timesOut), timesIn]
}

def lJustify(s, n) { return (s + " " * n).run(0, n.max(s.size())) }
def rJustify(s, n) { return (" " * n.max(s.size()) + s).run(s.size()) }

def runBenchmarks(out, table) {
  measure(empty)
  #def emptyTime := measure(empty)
  #out.println("Empty: " + emptyTime)
  for name => routine in table {
    out.print(lJustify(name, 20), " ")
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
