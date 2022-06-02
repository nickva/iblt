% @copyright 2007-2019 Zuse Institute Berlin

%   Licensed under the Apache License, Version 2.0 (the "License");
%   you may not use this file except in compliance with the License.
%   You may obtain a copy of the License at
%
%       http://www.apache.org/licenses/LICENSE-2.0
%
%   Unless required by applicable law or agreed to in writing, software
%   distributed under the License is distributed on an "AS IS" BASIS,
%   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%   See the License for the specific language governing permissions and
%   limitations under the License.

%% @author Thorsten Schuett <schuett@zib.de>
%% @doc    Utility Functions.
%% @end
-module(util).

-author('schuett@zib.de').

-export([log2/1, log1p/1, pow1p/2, bin_xor/2, bin_or/2, bin_and/2]).

-spec log2(X :: number()) -> float().
% use hard-coded math:log10(2)
log2(X) -> math:log10(X) / 0.3010299956639812.

%% from: David Goldberg. 1991. What every computer scientist should know
%%       about floating-point arithmetic. ACM Comput. Surv. 23, 1
%%       (March 1991), 5-48. DOI=<a href="http://dx.doi.org/10.1145/103162.103163">10.1145/103162.103163</a>
-spec log1p(X :: number()) -> float().
log1p(X) ->
    W = 1 + X,
    if
        W == 1 -> float(X);
        true -> X * math:log(W) / (W - 1)
    end.

%% @doc Calculates (1 - X^Y) more exactly, especially for X^Y near 1
%%      (only really usefull for 0 &lt; X &lt; 1 - for the rest, use math:pow/2).
%%      Uses the series representation of 1 - X^Y
%%      1-X^Y = sum_(i=1)^infinity (- Y^i * log^i(X) / (i!))
%% from: <a href="http://www.wolframalpha.com/input/?i=series+x^y">Wolfram Alpha for x^y</a>
-spec pow1p(X :: float(), Y :: float()) -> float().
pow1p(X, Y) when X >= 0 andalso Y == 0 ->
    0.0;
pow1p(X, Y) when X == 0 andalso Y /= 0 ->
    1.0;
pow1p(X, Y) when X > 0 andalso Y /= 0 ->
    % the difference between the terms for i and (i+1) is ln(X)/((i+1)*N)
    YxLnX = Y * math:log(X),
    pow1p_(-YxLnX, YxLnX, 2, -YxLnX).

-spec pow1p_(Prev :: float(), YxLnX :: float(), I :: pos_integer(), PrevSum :: float()) ->
    float().
pow1p_(Prev, YxLnX, CurI, Sum) ->
    Cur = Prev * YxLnX / CurI,
    NextSum = Sum + Cur,
    if
        NextSum == Sum ->
            Sum;
        true ->
            pow1p_(Cur, YxLnX, CurI + 1, NextSum)
    end.

%% @doc Binary XOR for the two bitstrings, even for big bitstrings where the
%%      conversion to an integer fails.
%%      Note: 0's are appended if the sizes do not match.
-spec bin_xor(bitstring(), bitstring()) -> bitstring().
bin_xor(Binary1, Binary2) ->
    bin_op(Binary1, Binary2, fun erlang:'bxor'/2).

%% @doc Binary OR for the two bitstrings, even for big bitstrings where the
%%      conversion to an integer fails.
%%      Note: 0's are appended if the sizes do not match.
-spec bin_or(bitstring(), bitstring()) -> bitstring().
bin_or(Binary1, Binary2) ->
    bin_op(Binary1, Binary2, fun erlang:'bor'/2).

%% @doc Binary AND for the two bitstrings, even for big bitstrings where the
%%      conversion to an integer fails.
%%      Note: 0's are appended if the sizes do not match.
-spec bin_and(bitstring(), bitstring()) -> bitstring().
bin_and(Binary1, Binary2) ->
    bin_op(Binary1, Binary2, fun erlang:'band'/2).

%% @doc Generic binary operations for the two bitstrings, even for big
%%      bitstrings where the conversion to an integer fails.
%%      Note: 0's are appended if the sizes do not match.
-spec bin_op(bitstring(), bitstring(), fun((integer(), integer()) -> integer())) ->
    bitstring().
bin_op(Binary1, Binary2, BinOp) ->
    BitSize1 = bit_size(Binary1),
    BitSize2 = bit_size(Binary2),
    ResSize = max(BitSize1, BitSize2),
    % up to (at least) Erlang 18.3, there is an upper limit of converting
    % binaries to integers or if this works the following bxor/2 will fail
    if
        ResSize =< 16#1FFFFC0 ->
            <<BinNr1:BitSize1/little>> = Binary1,
            <<BinNr2:BitSize2/little>> = Binary2,
            ResNr = BinOp(BinNr1, BinNr2),
            <<ResNr:ResSize/little>>;
        BitSize1 =:= BitSize2 ->
            % split the binary and bxor each part
            RestSize = BitSize1 rem 16#1FFFFC0,
            <<BinNr1:RestSize/little, Bin1TL/binary>> = Binary1,
            <<BinNr2:RestSize/little, Bin2TL/binary>> = Binary2,
            ResNr = BinOp(BinNr1, BinNr2),
            bin_op(Bin1TL, Bin2TL, BinOp, <<ResNr:RestSize/little>>);
        true ->
            % first bring the binaries to the same size, then try again:
            Bin1Large = <<Binary1/bitstring, 0:(ResSize - BitSize1)/little>>,
            Bin2Large = <<Binary2/bitstring, 0:(ResSize - BitSize2)/little>>,
            bin_op(Bin1Large, Bin2Large, BinOp)
    end.

%% @doc Helper for bin_op/3.
%%      Note: We cannot use erlang:list_to_binary/1 either since that suffers
%%            from the same problem with big binaries.
-spec bin_op(
    binary(),
    binary(),
    fun((integer(), integer()) -> integer()),
    ResultAcc :: bitstring()
) -> bitstring().
bin_op(<<>>, <<>>, _BinOp, Acc) ->
    Acc;
bin_op(Binary1, Binary2, BinOp, Acc) ->
    <<BinNr1:16#1FFFFC0/little, Bin1TL/binary>> = Binary1,
    <<BinNr2:16#1FFFFC0/little, Bin2TL/binary>> = Binary2,
    ResNr = BinOp(BinNr1, BinNr2),
    bin_op(Bin1TL, Bin2TL, BinOp, <<Acc/bitstring, ResNr:16#1FFFFC0/little>>).
