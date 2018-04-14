#lang scribble/manual

@(require
  "../base.rkt"
  "../drawings.rkt"
  pict/convert)

@title{A scale-invariant concurrency model}

A @tech{process} is a concurrency primitive based on lightweight
@rtech{threads} with extended messaging capabilities. Processes communicate
through synchronous, one-way value exchange. Either the sender or receiver can
initiate. One side waits to offer an exchange and the other side waits to
accept.

Senders can offer to @emph{give} values to passive takers, but receivers can
also offer to @emph{take} values from passive senders. This generalized model
of communication enables push- and pull-based messaging patterns independent
of the direction of data flow. When a pair of processes perform complementary
operations, the two synchronize and resume evaluation as the exchanged value
is delivered.

@section{A calculus of mediated exchange}

The intransitivity of bare channel synchronization complicates the semantics
of mediated operations such as forwarding. The following examples illustrate
this problem in terms of a forwarding operation.

With channels, the giver blocks to put a value into the forwarder while the
taker blocks to get a value from the forwarder. The forwarder accepts a value
from the giver as the giver unblocks ahead of the taker. The intended
synchronization is now impossible.

@(named-seqs
  ["giver" (ch-put "v" #:into "ch1") (punct "Ø")]
  ["forwader" (ch-get #:from "ch1" "v") (ch-put "v" #:into "ch2")]
  ["taker" (ch-get #:from "ch2" "v") (punct "Ø")])

In the other direction, the emitter blocks to put a value into the forwarder
while the receiver blocks to get a value from the forwarder. The forwarder
accepts a value from the emitter as the emitter unblocks ahead of the
receiver. Again, the intended synchronization becomes impossible.

@(named-seqs
  ["emiter" (ch-put "v" #:into "ch1") (punct "Ø")]
  ["forwarder" (ch-get #:from "ch1" "v") (ch-put "v" #:into "ch2")]
  ["receiver" (ch-get #:from "ch2" "v") (punct "Ø")])

Exchangers are an alternative to bare channels that preserve synchronization
across mediated exchanges by deferring the synchronizing operation until all
sides have committed to the exchange.

@subsection{Primitive operations}

@(code-pict-def
  @racket[(make-exchanger) (code:comment "ex")]
  (exchanger))

An exchanger contains a control channel and a data channel.

@(code-pict-def
  @racket[(offer ex1 #:to ex2)]
  (offer "ex1" #:to "ex2"))

A thread can offer one exchanger to another by putting the first into the
control channel of the second.

@(code-pict-def
  @racket[(accept #:from ex) (code:comment "ex*")]
  (accept #:from "ex" "ex*"))

A thread can accept an exchanger by getting it from the control channel of
another.

@(code-pict-def
  @racket[(put v #:into ex)]
  (put "v" #:into "ex"))

A thread can put a value into the data channel of an exchanger.

@(code-pict-def
  @racket[(get #:from ex) (code:comment "v")]
  (get #:from "ex" "v"))

A thread can get a value from the data channel of an exchanger.

@subsection{Process exchangers}

A process has two exchangers: one for transmitting and another for receiving.

@(code-pict-defs
  [@racket[(giver tx rx v)]
   (seq (offer "tx" #:to "rx") (put "v" #:into "tx"))]
  [@racket[(taker rx)]
   (seq (accept #:from "rx" "tx") (get #:from "tx" "v"))])

In a give-take exchange, a giver offers its transmitting exchanger to the
receiving exchanger of a taker. After the taker commits to the exchange by
accepting the offer, a single value flows through the transmitting exchanger
from giver to taker.

@(code-pict-defs
  [@racket[(receiver rx tx)]
   (seq (offer "rx" #:to "tx") (get #:from "rx" "v"))]
  [@racket[(emitter tx v)]
   (seq (accept #:from "tx" "rx") (put "v" #:into "rx"))])

In a receive-emit exchange, a receiver offers its receiving exchanger to the
transmitting exchanger of an emitter. After the emitter commits to the
exchange by accepting the offer, a single value flows through the receiving
exchanger from emitter to receiver.

@(code-pict-def
  @racket[(forwarder ex1 ex2)]
  (seq (accept #:from "ex1" "ex") (offer "ex" #:to "ex2")))

In a forwarding exchange, a mediator accepts an exchanger from one exchanger
and then offers it to another.

@(code-pict-def
  @racket[(coupler rx tx [ex (make-exchanger)])]
  (seq (offer "ex" #:to "rx") (offer "ex" #:to "tx")))

In a coupling exchange, a mediator offers an exchanger to two others.

@subsection{Transitive synchronization}

@subsubsection{Forwarding from giver to taker}

@(named-seqs
  ["giver" (offer "tx" #:to "ex1") (put "v" #:into "tx")]
  ["forwarder" (accept #:from "ex1" "tx") (offer "tx" #:to "ex2")]
  ["taker" (accept #:from "ex2" "tx") (get #:from "tx" "v")])

The giver offers its transmitting exchanger to the forwarder and then blocks
to put a value into the exchanger. The forwarder accepts the exchanger from
the giver and then offers it to the taker. The taker accepts the giver's
transmitting exchanger from the forwarder and then gets a value as the giver
unblocks.

Data and control flow from the giver to the taker. Until the taker is ready to
accept, the forwarder blocks to offer and the giver blocks to put, preventing
the giver from prematurely synchronizing on the forwarder.

@subsubsection{Forwarding from emitter to receiver}

@(named-seqs
  ["receiver" (offer "rx" #:to "ex1") (get #:from "rx" "v")]
  ["forwarder" (accept #:from "ex1" "rx") (offer "rx" #:to "ex2")]
  ["emitter" (accept #:from "ex2" "rx") (put "v" #:into "rx")])

The receiver offers its receiving exchanger to the forwarder and then blocks
to get a value from the exchanger. The forwarder accepts the exchanger from
the receiver and then offers it to the emitter. The emitter accepts the
receiver's receiving exchanger from the forwarder and then puts a value into
it as the receiver unblocks.

Data flows from emitter to receiver, but control flows in the opposite
direction. Until the emitter is ready to accept, the forwarder blocks to offer
and the receiver blocks to get, preventing the emitter from prematurely
synchronizing on the forwarder.

@subsubsection{Coupling emitter to taker}

Couplers are forwarders for emit-take exchanges. The coupler offers an
exchanger to a taker and then an emitter. The emitter and taker both accept
the exchanger from the coupler and then synchronize by exchanging a value
through the shared exchanger.

@(named-seqs
  ["coupler" (offer "ex" #:to "rx") (offer "ex" #:to "tx")]
  ["emitter" (accept #:from "tx" "ex") (put "v" #:into "ex")]
  ["taker" (accept #:from "rx" "ex") (get #:from "ex" "v")])
