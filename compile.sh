rm *.tap
pasmo --bin fro.s fro.b
pasmo --tapbas fro.s fro.tap
ls -lag *.b
