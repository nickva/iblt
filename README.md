Invertible Bloom Lookup Tables
=====

This is the IBLT implementation extracted from [Scalaris](https://github.com/scalaris-team/scalaris.git)

IBLT description can be found [here](https://arxiv.org/abs/1101.2245)

Building
====
```
rebar3 compile
```

Trying it out
====
```
rebar3 shell
>
  I = iblt:new(5, 100),
  I2 = iblt:insert(I, <<"abc">>, 42),
  I3 = iblt:insert(I2, <<"def">>, 9000),
  iblt:list_entries(I3).

[{<<"abc">>,42},{<<"def">>,9000}]
```

