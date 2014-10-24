let test_show m t =
  ignore (Tc.show m t)

let test_cstruct m t =
  let str = Tc.write_string m t in
  let t'  = Tc.read_string m str in
  OUnit.assert_equal
    ~msg:"idempotent string conversion"
    ~cmp:(Tc.equal m)
    t t'

let test_json m t =
  let j = Tc.to_json m t in
  let str = Ezjsonm.to_string j in
  let j' = Ezjsonm.from_string str in
  let t' = Tc.of_json m j' in
  OUnit.assert_equal
    ~msg:"idempotent string conversion"
    ~cmp:(Tc.equal m)
    t t'

let random_int i =
  Printf.printf "XXXX random_int(%d)\n" i;
  if i <= 1 then 0
  else Random.int i

let random_string len =
  let s = String.create (random_int len) in
  for i = 0 to String.length s - 1 do
    s.[i] <- Char.chr (random_int 256)
  done;
  s

let random_list len gen =
  Array.to_list (Array.init len gen)

let string f () =
  let m = (module Tc.S: Tc.I0 with type t = string) in
  for i = 0 to 100 do
    f m (random_string 2043)
  done

let list f () =
  let m = (module Tc.App1(Tc.L)(Tc.I): Tc.I0 with type t = int list) in
  f m [];
  f m (random_list 1024 (fun i -> random_int ((i+1)*2)))

let pair f () =
  let m =
    (module Tc.App2(Tc.P)(Tc.App1(Tc.O)(Tc.U))(Tc.App1(Tc.L)(Tc.S)):
      Tc.I0 with type t = unit option * string list)
  in
  f m (Some (), [""]);
  f m (None, []);
  f m (Some (), random_list 1024 (fun _ -> random_string 2048))

let queue f () =
  let module Q = struct
    include Queue
    let to_list q =
      Queue.fold (fun q x -> x :: q) [] q
      |> List.rev
    let of_list l =
      let q = Queue.create () in
      List.iter (fun x -> Queue.push x q) l;
      q
    include Tc.L1(struct
        type 'a t = 'a Queue.t
        let to_list = to_list
        let of_list = of_list
      end)
  end in
  let m = (module Tc.App1(Q)(Tc.I): Tc.I0 with type t = int Queue.t) in
  f m (Q.of_list []);
  f m (Q.of_list (random_list 1024 (fun i -> i)))

let () =
  let suite k gen =
    k   , [
      "show functions"    , `Quick, gen test_show;
      "cstructs functions", `Quick, gen test_cstruct;
      "JSON functions"    , `Quick, gen test_json;
    ]
  in
  Alcotest.run "tc" [
    suite "string" string;
    suite "list"   list;
    suite "pair"   pair;
    suite "queue"  queue;
  ]